import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/screens/main_navigation.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart';
import 'support/unavailable_sqlite.dart';

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
      final profile = ProfileService(users, store: local);
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
      final session = SessionService(sessions, store: local);
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

      await tester.tap(find.text('Profile').hitTestable().last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A previous change is not confirmed'),
        findsOneWidget,
      );

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
      // Reconnect starts bounded connection checks independently of widget
      // animations. Let their timeout futures finish after disposal too.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(events.hasListener, isFalse);
    },
  );
}
