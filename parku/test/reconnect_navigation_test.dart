import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/screens/main_navigation.dart';
import 'package:parku/screens/my_parking.dart';
import 'package:parku/screens/no_active_parking.dart';
import 'package:parku/screens/parking_list.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/widgets/user_error_notice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart';
import 'support/unavailable_sqlite.dart';
import 'support/navigation_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    useUnavailableSqlite();
    await Supabase.initialize(
      url: 'https://test.invalid',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        pkceAsyncStorage: MemoryAuthStorage(),
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Map unavailable in this test'}),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    await signInAs(Supabase.instance.client, 'user-1');
  });
  tearDown(() async => Supabase.instance.dispose());

  testWidgets(
    'Profile and Home open the empty parking screen offline without a saved stay',
    (tester) async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => ['none']);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final client = Supabase.instance.client;
      final local = UserLocalStore.memory(client);
      final users = UnstableUserRepository();
      final profile = ProfileService(
        users,
        store: local,
        checkConnection: () async => users.online,
      );
      await profile.getProfile();
      await profile.getVehicles();
      users.online = false;
      final service = SessionService(
        UnstableSessionRepository(client),
        store: local,
        checkConnection: () async => false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(
            profileService: profile,
            sessionService: service,
            connectionChanges: const Stream<List<ConnectivityResult>>.empty(),
            checkConnection: () async => [ConnectivityResult.none],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapNavigation(tester, 'Profile');
      await tester.ensureVisible(find.text('My parking'));
      await tester.tap(find.text('My parking'));
      await tester.pumpAndSettle();
      final emptyPage = find.byType(NoActiveParkingScreen);
      expect(
        tester.widget<NoActiveParkingScreen>(emptyPage).isFromCache,
        isTrue,
      );
      expect(find.text('No active parking saved'), findsOneWidget);
      expect(find.byType(UserErrorNotice), findsNothing);

      await tapNavigation(tester, 'Map');
      await tester.ensureVisible(find.text('View my parking'));
      await tester.tap(find.text('View my parking'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NoActiveParkingScreen>(emptyPage).isFromCache,
        isTrue,
      );
      expect(find.text('No active parking saved'), findsOneWidget);
      expect(find.byType(UserErrorNotice), findsNothing);
      await tester.ensureVisible(find.text('Find parking'));
      await tester.tap(find.text('Find parking'));
      await tester.pumpAndSettle();
      expect(find.byType(ParkingListScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'My parking shows and edits a queued start without going online',
    (tester) async {
      final client = Supabase.instance.client;
      final local = UserLocalStore.memory(client);
      final users = UnstableUserRepository();
      await users.addVehicle(VehicleType.car, 'ABC123');
      final profile = ProfileService(
        users,
        store: local,
        checkConnection: () async => users.online,
      );
      await profile.getProfile();
      await profile.getVehicles();
      users.online = false;
      final now = DateTime(2026, 11, 26, 12);
      final sessions = UnstableSessionRepository(client);
      final service = SessionService(
        sessions,
        store: local,
        checkConnection: () async => false,
        currentTime: () => now,
      );
      await service.saveParking(
        Parking.fromMap({
          'id': 'parking-1',
          'name': 'City U Parking',
          'address': 'Calle 20',
          'opening_time': '08:00',
          'closing_time': '17:00',
        }),
      );
      await expectLater(
        service.startParking(
          parkingId: 'parking-1',
          vehicleId: 'vehicle-1',
          pickupTime: now.add(const Duration(hours: 2)),
          parkingName: 'City U Parking',
          vehicleType: 'car',
          vehiclePlate: 'ABC123',
        ),
        throwsA(isA<QueuedChange>()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(
            profileService: profile,
            sessionService: service,
            currentTime: () => now,
            connectionChanges: const Stream<List<ConnectivityResult>>.empty(),
            checkConnection: () async => [ConnectivityResult.none],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapNavigation(tester, 'Profile');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('My parking'));
      await tester.tap(find.text('My parking'));
      await tester.pumpAndSettle();

      final parking = find.byType(MyParkingScreen);
      expect(tester.widget<MyParkingScreen>(parking).session, isNull);
      expect(find.text('City U Parking'), findsOneWidget);
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byType(UserErrorNotice), findsOneWidget);
      expect(find.text('TIME UNTIL REQUESTED PICKUP'), findsOneWidget);

      await tester.ensureVisible(find.text('Change pickup time'));
      await tester.tap(find.text('Change pickup time'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<String>));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2:30 PM').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save pickup time'));
      await tester.tap(find.text('Save pickup time'));
      await tester.pumpAndSettle();
      final edited = now.add(const Duration(hours: 2, minutes: 30)).toUtc();
      expect(service.pendingStart?.pickupTime, edited);
      expect(
        tester.widget<MyParkingScreen>(parking).requestedPickupTime,
        edited,
      );
      expect(sessions.starts, 0);

      await tester.ensureVisible(find.text('Cancel parking request'));
      await tester.tap(find.text('Cancel parking request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      expect(service.pendingStart, isNull);
      expect(parking, findsNothing);
      expect(sessions.starts, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    },
  );

  testWidgets(
    'returning online updates the actual vehicle screen and verifies the previous stay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = StreamController<List<ConnectivityResult>>();
      addTearDown(events.close);
      final client = Supabase.instance.client;
      final local = UserLocalStore.memory(client);
      final users = UnstableUserRepository();
      final profile = ProfileService(
        users,
        store: local,
        checkConnection: () async => null,
      );
      await profile.getProfile();
      await profile.getVehicles();
      users.loseReply = true;
      users.disconnectAfterWrite = true;
      await expectLater(
        profile.addVehicle(VehicleType.car, 'ABC123'),
        throwsA(isA<ConnectionFailure>()),
      );
      final sessions = UnstableSessionRepository(client)
        ..loseReply = true
        ..disconnectAfterWrite = true;
      final session = SessionService(
        sessions,
        store: local,
        checkConnection: () async => null,
      );
      await expectLater(
        session.startParking(
          parkingId: 'parking-1',
          vehicleId: 'vehicle-1',
          pickupTime: DateTime.now().add(const Duration(hours: 2)),
        ),
        throwsA(isA<ConnectionFailure>()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(
            profileService: profile,
            sessionService: session,
            connectionChanges: events.stream,
            checkConnection: () async => [ConnectivityResult.none],
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
          .clearSnackBars();

      await tester.pumpAndSettle();

      await tapNavigation(tester, 'Profile');
      await tester.pumpAndSettle();
      expect(profile.queuedChanges.single['kind'], 'add_vehicle');
      expect(find.textContaining('Changes saved on this device'), findsNothing);

      users.online = true;
      sessions.online = true;
      events.add([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(profile.pendingChange, isNull);
      expect(session.pendingRequest, isNull);
      await tester.ensureVisible(find.text('My vehicles'));
      await tester.tap(find.text('My vehicles'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      expect(users.writes, 1);
      expect(sessions.starts, 1);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      // Let pending connection timeouts finish after closing the screen.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(events.hasListener, isFalse);
    },
  );
  testWidgets('saved profile, vehicle and parking requests sync on reconnect', (
    tester,
  ) async {
    final client = Supabase.instance.client;
    final store = UserLocalStore.memory(client);
    var connected = true;
    final events = StreamController<List<ConnectivityResult>>();
    addTearDown(events.close);
    final users = UnstableUserRepository();
    await users.addVehicle(VehicleType.motorcycle, 'ABC12D');
    users.writes = 0;
    final profile = ProfileService(
      users,
      store: store,
      checkConnection: () async => connected,
    );
    await profile.getProfile();
    await profile.getVehicles();
    final sessions = UnstableSessionRepository(client);
    final service = SessionService(
      sessions,
      store: store,
      checkConnection: () async => connected,
    );
    connected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationScreen(
          profileService: profile,
          sessionService: service,
          connectionChanges: events.stream,
          checkConnection: () async => [
            connected ? ConnectivityResult.wifi : ConnectivityResult.none,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapNavigation(tester, 'Profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Juan');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(users.writes, 0);
    expect(profile.queuedChanges, hasLength(1));
    await tester.ensureVisible(find.text('My vehicles'));
    await tester.tap(find.text('My vehicles'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add vehicle'));
    await tester.tap(find.text('Add vehicle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'DEF456');
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Car · DEF456'), findsOneWidget);
    expect(find.textContaining('Pending registration'), findsOneWidget);
    expect(profile.queuedChanges, hasLength(2));
    expect(users.writes, 0);
    await expectLater(
      service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: DateTime.now().add(const Duration(hours: 2)),
      ),
      throwsA(isA<QueuedChange>()),
    );
    connected = true;
    events.add([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(users.profile.fullName, 'Juan');
    expect(profile.queuedChanges, isEmpty);
    expect(service.pendingRequest, isNull);
    expect(users.writes, 2);
    expect(users.vehicles.map((vehicle) => vehicle.plate), [
      'ABC12D',
      'DEF456',
    ]);
    expect(sessions.starts, 1);
    expect(find.text('DEF456'), findsOneWidget);
    expect(find.textContaining('Pending registration'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
