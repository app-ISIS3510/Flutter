import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/personal_data_repository.dart';
import 'package:parku/repositories/session_history_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/screens/profile/add_vehicle_screen.dart';
import 'package:parku/screens/profile/edit_profile_screen.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/screens/profile/vehicles_screen.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/widgets/user_error_notice.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart';

class TrackingUsers extends UnstableUserRepository {
  int reads = 0;
  int deletions = 0;
  bool stalled = false;
  bool disconnectAfterDelete = false;
  final reply = Completer<UserProfile>();

  @override
  Future<UserProfile> getProfile() {
    reads++;
    return stalled ? reply.future : super.getProfile();
  }

  @override
  Future<List<Vehicle>> getVehicles() {
    reads++;
    return super.getVehicles();
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await super.deleteVehicle(id);
    deletions++;
    if (disconnectAfterDelete) online = false;
  }

  @override
  Future<bool> isAdmin() {
    reads++;
    return super.isAdmin();
  }
}

class FailedQueueStore extends UserLocalStore {
  FailedQueueStore(super.client) : super.memory();

  @override
  Future<void> write(String key, Map<String, dynamic> data) async {
    if (key == 'profile_queue' || key == 'session_request') {
      throw const FileSystemException('Storage full');
    }
    await super.write(key, data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SupabaseClient client;
  late TrackingUsers users;
  late UnstableSessionRepository sessions;
  late UserLocalStore store;
  late PersonalDataRepository local;
  var connected = true;
  final now = DateTime.utc(2026, 11, 18, 15);
  final pickup = now.add(const Duration(hours: 2));

  ProfileService profileService() => ProfileService(
    users,
    local: local,
    store: UserLocalStore(client, getDirectory: () async => directory),
    checkConnection: () async => connected,
  );

  SessionService sessionService() => SessionService(
    sessions,
    store: UserLocalStore(client, getDirectory: () async => directory),
    historyRepository: SessionHistoryRepository(
      client,
      getDirectory: () async => directory,
    ),
    checkConnection: () async => connected,
    currentTime: () => now,
    requestTimeout: const Duration(milliseconds: 30),
  );

  Future<void> savePersonalData() async {
    await users.addVehicle(VehicleType.car, 'ABC123');
    final service = profileService();
    await service.getProfile();
    await service.getVehicles();
    users.writes = 0;
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-pending-changes-');
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    users = TrackingUsers();
    sessions = UnstableSessionRepository(client);
    store = UserLocalStore(client, getDirectory: () async => directory);
    local = PersonalDataRepository(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/personal.db',
    );
    connected = true;
  });

  tearDown(() async {
    if (users.stalled && !users.reply.isCompleted) {
      users.reply.complete(users.profile);
      await Future<void>.delayed(Duration.zero);
    }
    await local.close();
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test('offline profile opens from disk without any remote request', () async {
    await savePersonalData();
    await local.close();
    connected = false;
    users.stalled = true;
    final reads = users.reads;
    final controller = ProfileController(profileService());
    addTearDown(controller.dispose);
    await controller.load().timeout(const Duration(seconds: 1));
    expect(controller.profile?.fullName, 'Alex Rivera');
    expect(controller.selectedVehicle?.plate, 'ABC123');
    expect(controller.loading, isFalse);
    expect(controller.usingSavedData, isTrue);
    expect(controller.isAdmin, isFalse);
    expect(users.reads, reads);
  });

  test(
    'offline without a saved profile stops loading and shows no profile',
    () async {
      connected = false;
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.profile, isNull);
      expect(controller.vehicles, isEmpty);
      expect(controller.loading, isFalse);
      expect(controller.error, contains('No saved profile'));
      expect(users.reads, 0);
    },
  );

  test(
    'an offline account cannot see another account saved on the device',
    () async {
      await savePersonalData();
      await signInAs(client, 'user-2');
      connected = false;
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.profile, isNull);
      expect(controller.vehicles, isEmpty);
    },
  );

  test(
    'offline cars and motorcycles survive reopening and sync only once',
    () async {
      await profileService().getProfile();
      await profileService().getVehicles();
      connected = false;
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      expect(await controller.addVehicle(VehicleType.car, 'ABC123'), isTrue);
      expect(await controller.addVehicle(VehicleType.car, ' abc123 '), isTrue);
      expect(
        await controller.addVehicle(VehicleType.motorcycle, 'XYZ45D'),
        isTrue,
      );
      expect(controller.changeQueued, isTrue);
      expect(users.writes, 0);
      expect(controller.selectedVehicle, isNull);
      expect(await store.read('profile_request'), isNull);

      final reopened = ProfileController(profileService());
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.vehicles, isEmpty);
      expect(reopened.pendingVehicleRegistrations.map((item) => item.plate), [
        'ABC123',
        'XYZ45D',
      ]);
      connected = true;
      await reopened.load();
      expect(reopened.pendingVehicleRegistrations, isEmpty);
      expect(reopened.vehicles.map((vehicle) => vehicle.plate), [
        'ABC123',
        'XYZ45D',
      ]);
      expect(reopened.service.queuedChanges, isEmpty);
      expect(users.writes, 2);
    },
  );

  test(
    'offline edits survive reopening and the latest details are synchronized',
    () async {
      await savePersonalData();
      connected = false;
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      await controller.load();
      expect(
        await controller.saveProfile('First name', 'first@example.com'),
        isTrue,
      );
      expect(await controller.saveProfile('Juan', 'juan@example.com'), isTrue);
      expect(controller.changeQueued, isTrue);
      expect(controller.profile?.fullName, 'Alex Rivera');
      expect(controller.queuedProfileEdit, (
        name: 'Juan',
        email: 'juan@example.com',
      ));
      expect(controller.profileNotice, isNull);
      expect(users.writes, 0);
      final reopened = ProfileController(profileService());
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.queuedProfileEdit, controller.queuedProfileEdit);
      connected = true;
      await reopened.load();
      expect(reopened.profile?.fullName, 'Juan');
      expect(reopened.queuedProfileEdit, isNull);
      expect(reopened.service.queuedChanges, isEmpty);
      expect(users.writes, 1);
    },
  );

  test(
    'vehicle selection and deletion are queued separately and sent in order',
    () async {
      await savePersonalData();
      await users.addVehicle(VehicleType.car, 'DEF456');
      await profileService().getVehicles();
      users.writes = 0;
      connected = false;
      final offline = ProfileController(profileService());
      addTearDown(offline.dispose);
      await offline.load();
      expect(offline.selectedVehicle?.id, 'vehicle-1');
      await expectLater(
        offline.service.selectVehicle('vehicle-2'),
        throwsA(isA<QueuedChange>()),
      );
      expect(await offline.deleteVehicle('vehicle-1'), isTrue);
      expect(offline.vehicles.single.id, 'vehicle-2');
      expect(offline.selectedVehicle, isNull);
      expect(users.writes, 0);
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.vehicles.single.id, 'vehicle-2');
      expect(controller.service.queuedChanges, hasLength(2));
      connected = true;
      await controller.load();
      expect(controller.selectedVehicle?.id, 'vehicle-2');
      expect(controller.vehicles.length, 1);
      expect(users.writes, 2);
      expect(controller.service.queuedChanges, isEmpty);
    },
  );

  test(
    'a confirmed deletion stays removed if the following refresh is offline',
    () async {
      await savePersonalData();
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      connected = false;
      await controller.load();
      expect(await controller.deleteVehicle('vehicle-1'), isTrue);
      connected = true;
      users.disconnectAfterDelete = true;
      await controller.load();
      expect(controller.vehicles, isEmpty);
      expect(controller.service.queuedChanges, isEmpty);
      expect(users.writes, 1);

      connected = false;
      final reopened = ProfileController(profileService());
      addTearDown(reopened.dispose);
      await reopened.load();
      expect(reopened.vehicles, isEmpty);
    },
  );

  test(
    'a lost profile response is checked before the queued change is sent again',
    () async {
      await savePersonalData();
      users.loseReply = true;
      users.disconnectAfterWrite = true;
      final controller = ProfileController(profileService());
      addTearDown(controller.dispose);
      await controller.load();
      expect(await controller.saveProfile('Juan', 'juan@example.com'), isTrue);
      expect(controller.changeQueued, isTrue);
      expect(users.writes, 1);
      users.online = true;
      await controller.load();
      expect(controller.profile?.fullName, 'Juan');
      expect(controller.service.queuedChanges, isEmpty);
      expect(controller.pendingChange, isNull);
      expect(users.writes, 1);
    },
  );

  test(
    'a failed disk write is not reported as a queued profile change or vehicle',
    () async {
      connected = false;
      final service = ProfileService(
        users,
        store: FailedQueueStore(client),
        checkConnection: () async => false,
      );
      final controller = ProfileController(service);
      addTearDown(controller.dispose);
      expect(await controller.saveProfile('Juan', 'juan@example.com'), isFalse);
      expect(controller.changeQueued, isFalse);
      expect(await controller.addVehicle(VehicleType.car, 'ABC123'), isFalse);
      expect(controller.changeQueued, isFalse);
      expect(controller.pendingVehicleRegistrations, isEmpty);
      expect(users.writes, 0);
    },
  );

  test(
    'a queued start is not active until reconnect and is sent only once',
    () async {
      connected = false;
      await expectLater(
        sessionService().startParking(
          parkingId: 'parking-1',
          vehicleId: 'vehicle-1',
          pickupTime: pickup,
        ),
        throwsA(isA<QueuedChange>()),
      );
      expect(sessions.starts, 0);
      final reopened = sessionService();
      expect(await reopened.getActiveSession(), isNull);
      expect(reopened.pendingRequest?['kind'], 'start');
      final editedPickup = pickup.add(const Duration(minutes: 30));
      await reopened.editQueuedStart(
        reopened.pendingStart!,
        pickupTime: editedPickup,
      );
      expect(sessions.starts, 0);
      final afterEdit = sessionService();
      expect(await afterEdit.getActiveSession(), isNull);
      expect(afterEdit.pendingStart?.pickupTime, editedPickup);
      connected = true;
      expect((await afterEdit.getActiveSession())?.pickupTime, editedPickup);
      await afterEdit.getActiveSession();
      expect(sessions.starts, 1);
      expect(await store.read('session_request'), isNull);
    },
  );

  test('canceling an offline start prevents any send on reconnect', () async {
    connected = false;
    final service = sessionService();
    await expectLater(
      service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
      ),
      throwsA(isA<QueuedChange>()),
    );
    await service.editQueuedStart(service.pendingStart!);
    expect(await store.read('session_request'), isNull);
    connected = true;
    expect(await sessionService().getActiveSession(), isNull);
    expect(sessions.starts, 0);
  });

  test(
    'a queued pickup change keeps the confirmed time until reconnect',
    () async {
      final service = sessionService();
      final active = await service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
      );
      connected = false;
      final nextTime = pickup.add(const Duration(hours: 1));
      await expectLater(
        service.changePickupTime(sessionId: active.id, pickupTime: nextTime),
        throwsA(isA<QueuedChange>()),
      );
      expect(sessions.changes, 0);
      expect((await service.getActiveSession())?.pickupTime, pickup);
      connected = true;
      expect((await sessionService().getActiveSession())?.pickupTime, nextTime);
      expect(sessions.changes, 1);
    },
  );

  test('a queued end preserves active parking and saves its summary after confirmation', () async {
    final service = sessionService();
    final active = await service.startParking(
      parkingId: 'parking-1',
      vehicleId: 'vehicle-1',
      pickupTime: pickup,
    );
    connected = false;
    await expectLater(
      service.endParking(sessionId: active.id, parkingName: 'City U Parking'),
      throwsA(isA<QueuedChange>()),
    );
    expect(sessions.ends, 0);
    expect((await service.getActiveSession())?.status, 'active');
    connected = true;
    final reopened = sessionService();
    expect(await reopened.getActiveSession(), isNull);
    expect(sessions.ends, 1);
    expect(
      (await reopened.getSavedSessions()).single.parkingName,
      'City U Parking',
    );
    expect(await store.read('session_request'), isNull);
  });

  test('a saved pickup time that has passed is not sent later', () async {
    connected = false;
    await expectLater(
      sessionService().startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: now.subtract(const Duration(minutes: 1)),
      ),
      throwsA(isA<QueuedChange>()),
    );
    connected = true;
    await expectLater(
      sessionService().getActiveSession(),
      throwsA(
        isA<ConnectionFailure>().having(
          (error) => error.message,
          'message',
          contains('has passed'),
        ),
      ),
    );
    expect(sessions.starts, 0);
    expect(await store.read('session_request'), isNull);
  });

  test(
    'reconnect cannot replay a request while its first send is still running',
    () async {
      sessions.startGate = Completer<void>();
      final service = sessionService();
      await expectLater(
        service.startParking(
          parkingId: 'parking-1',
          vehicleId: 'vehicle-1',
          pickupTime: pickup,
        ),
        throwsA(isA<QueuedChange>()),
      );
      await service.getActiveSession();
      expect(sessions.starts, 1);
      sessions.startGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect((await service.getActiveSession())?.status, 'active');
      expect(sessions.starts, 1);
    },
  );

  test('queued operations remain private after switching users', () async {
    connected = false;
    await expectLater(
      sessionService().startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
      ),
      throwsA(isA<QueuedChange>()),
    );
    await expectLater(
      profileService().updateProfile('Juan', 'juan@example.com'),
      throwsA(isA<QueuedChange>()),
    );
    await signInAs(client, 'user-2');
    connected = true;
    expect(await sessionService().syncPendingRequest(), isFalse);
    expect(await profileService().syncPendingChanges(), isFalse);
    expect(sessions.starts, 0);
    expect(users.writes, 0);
    await signInAs(client, 'user-1');
    await sessionService().syncPendingRequest();
    await profileService().syncPendingChanges();
    expect(sessions.starts, 1);
    expect(users.writes, 1);
  });

  test('two reconnect checks cannot send the same saved start twice', () async {
    connected = false;
    final service = sessionService();
    await expectLater(
      service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
      ),
      throwsA(isA<QueuedChange>()),
    );
    connected = true;
    sessions.startGate = Completer<void>();
    final sending = service.syncPendingRequest();
    await sessions.startReceived.future;
    expect(await service.syncPendingRequest(), isFalse);
    sessions.startGate!.complete();
    expect(await sending, isTrue);
    expect(sessions.starts, 1);
  });

  test('two reconnect checks share one pending profile save', () async {
    connected = false;
    final service = profileService();
    await expectLater(
      service.updateProfile('Juan', 'juan@example.com'),
      throwsA(isA<QueuedChange>()),
    );
    connected = true;
    users.profileGate = Completer<void>();
    final sending = service.syncPendingChanges();
    await users.profileReceived.future;
    expect(await service.syncPendingChanges(), isFalse);
    users.profileGate!.complete();
    expect(await sending, isTrue);
    expect(users.writes, 1);
  });

  test(
    'a queued pickup change cannot overwrite a change from another device',
    () async {
      final service = sessionService();
      final active = await service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
      );
      connected = false;
      await expectLater(
        service.changePickupTime(
          sessionId: active.id,
          pickupTime: pickup.add(const Duration(hours: 1)),
        ),
        throwsA(isA<QueuedChange>()),
      );
      final newer = pickup.add(const Duration(hours: 2));
      await sessions.updatePickupTime(sessionId: active.id, pickupTime: newer);
      sessions.changes = 0;
      connected = true;
      await expectLater(
        sessionService().getActiveSession(),
        throwsA(
          isA<ConnectionFailure>().having(
            (error) => error.message,
            'message',
            contains('changed on the server'),
          ),
        ),
      );
      expect(sessions.changes, 0);
      expect(sessions.sessions.single.pickupTime, newer);
      expect(await store.read('session_request'), isNull);
    },
  );

  testWidgets('saved profile stays visible during a stalled refresh', (
    tester,
  ) async {
    final memory = UserLocalStore.memory(client);
    final service = ProfileService(
      users,
      store: memory,
      checkConnection: () async => true,
    );
    await service.getProfile();
    await service.getVehicles();
    users.stalled = true;
    final controller = ProfileController(service);
    addTearDown(controller.dispose);
    final loading = controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          controller: controller,
          onNavTap: (_) {},
          onMyParking: () {},
          onAnalyticsDashboard: () {},
          onSignedOut: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 9));
    users.reply.complete(users.profile);
    await loading;
    await tester.pumpAndSettle();
  });

  testWidgets(
    'offline vehicle registration shows its pending status without a red notice',
    (tester) async {
      final controller = ProfileController(
        ProfileService(
          users,
          store: UserLocalStore.memory(client),
          checkConnection: () async => connected,
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      connected = false;
      await controller.load();
      expect(controller.usingSavedData, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: VehiclesScreen(controller: controller, onNavTap: (_) {}),
        ),
      );
      expect(find.byType(UserErrorNotice), findsNothing);
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.ensureVisible(find.text('Save vehicle'));
      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();
      expect(find.byType(AddVehicleScreen), findsNothing);
      expect(find.text('Car · ABC123'), findsOneWidget);
      expect(find.textContaining('Pending registration'), findsOneWidget);
      expect(find.byType(UserErrorNotice), findsNothing);
      expect(find.text('Use vehicle'), findsNothing);
      expect(users.writes, 0);

      connected = true;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.textContaining('Pending registration'), findsNothing);
      expect(find.text('Use vehicle'), findsOneWidget);
      expect(users.writes, 1);
    },
  );

  testWidgets(
    'offline deletion hides the card and shows a red pending notice',
    (tester) async {
      await users.addVehicle(VehicleType.car, 'ABC123');
      await users.addVehicle(VehicleType.car, 'DEF456');
      users.writes = 0;
      final controller = ProfileController(
        ProfileService(
          users,
          store: UserLocalStore.memory(client),
          checkConnection: () async => connected,
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();
      connected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: VehiclesScreen(controller: controller, onNavTap: (_) {}),
        ),
      );
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.byType(UserErrorNotice), findsNothing);
      await tester.tap(find.text('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete ABC123?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsNothing);
      expect(find.text('DEF456'), findsOneWidget);
      expect(
        find.widgetWithText(
          UserErrorNotice,
          'ABC123 was removed on this device. The deletion will sync when you reconnect.',
        ),
        findsOneWidget,
      );
      expect(users.writes, 0);
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(controller.service.queuedChanges, hasLength(1));
      expect(find.byType(UserErrorNotice), findsNothing);

      connected = true;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsNothing);
      expect(find.byType(UserErrorNotice), findsNothing);
      expect(users.vehicles.single.plate, 'DEF456');
      expect(users.deletions, 1);
    },
  );

  testWidgets('offline profile edits appear immediately with one red notice', (
    tester,
  ) async {
    final service = ProfileService(
      users,
      store: UserLocalStore.memory(client),
      checkConnection: () async => connected,
    );
    await service.getProfile();
    await service.getVehicles();
    connected = false;
    final controller = ProfileController(service);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          controller: controller,
          onNavTap: (_) {},
          onMyParking: () {},
          onAnalyticsDashboard: () {},
          onSignedOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alex Rivera'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Juan');
    await tester.enterText(find.byType(TextFormField).last, 'juan@example.com');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('Alex Rivera'), findsNothing);
    expect(find.textContaining('Changes saved on this device'), findsNothing);
    expect(find.byType(UserErrorNotice), findsOneWidget);
    expect(
      find.widgetWithText(
        UserErrorNotice,
        'Your profile changes are saved on this device. They will sync when you reconnect.',
      ),
      findsOneWidget,
    );
    expect(find.text('Profile updated.'), findsNothing);
    expect(users.writes, 0);
  });
}
