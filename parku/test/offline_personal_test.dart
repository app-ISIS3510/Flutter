import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/personal_data_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SupabaseClient client;
  late UnstableUserRepository remote;
  late PersonalDataRepository local;
  late UserLocalStore store;
  late ProfileService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-offline-profile-');
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    remote = UnstableUserRepository();
    local = PersonalDataRepository(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/personal.db',
    );
    store = UserLocalStore(client, getDirectory: () async => directory);
    service = ProfileService(remote, local: local, store: store);
  });
  tearDown(() async {
    await local.close();
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'profile and vehicles can be read after reopening SQLite without internet',
    () async {
      await remote.addVehicle(VehicleType.car, 'ABC123');
      await service.getProfile();
      await service.getVehicles();
      await local.close();
      remote.online = false;
      final reopened = ProfileService(remote, local: local, store: store);

      expect((await reopened.getProfile()).fullName, 'Alex Rivera');
      expect((await reopened.getVehicles()).single.plate, 'ABC123');
      expect(reopened.usingSavedData, isTrue);
      expect(await reopened.isAdmin(), isFalse);
    },
  );

  test(
    'an empty downloaded vehicle list differs from having no saved data',
    () async {
      remote.online = false;
      await expectLater(
        service.getVehicles(),
        throwsA(isA<ConnectionFailure>()),
      );
      remote.online = true;
      expect(await service.getVehicles(), isEmpty);
      remote.online = false;
      expect(await service.getVehicles(), isEmpty);
      expect(service.vehiclesFromCache, isTrue);
    },
  );

  test('SQLite and memory fallback never mix accounts', () async {
    await remote.addVehicle(VehicleType.car, 'ABC123');
    await service.getProfile();
    await service.getVehicles();
    await signInAs(client, 'user-2');
    remote.profile = const UserProfile(
      id: 'user-2',
      fullName: 'Second user',
      email: 'second@example.com',
    );
    remote.vehicles = [];
    await service.getVehicles();
    remote.online = false;

    await expectLater(service.getProfile(), throwsA(isA<ConnectionFailure>()));
    expect(await service.getVehicles(), isEmpty);
    await signInAs(client, 'user-1');
    expect((await service.getProfile()).id, 'user-1');
    expect((await service.getVehicles()).single.plate, 'ABC123');
  });

  test(
    'an offline save keeps the form draft without sending a mutation',
    () async {
      remote.online = false;
      await expectLater(
        service.updateProfile('New name', 'new@example.com'),
        throwsA(isA<ConnectionFailure>()),
      );

      final reopened = ProfileService(
        remote,
        local: local,
        store: UserLocalStore(client, getDirectory: () async => directory),
      );
      await reopened.restorePendingChange();
      expect(reopened.profileDraft?['name'], 'New name');
      expect(reopened.pendingChange, isNull);
      expect(remote.writes, 0);
    },
  );

  test('a lost profile response is confirmed from the server', () async {
    remote.loseReply = true;
    final saved = await service.updateProfile('Juan', 'juan@example.com');

    expect(saved.fullName, 'Juan');
    expect(service.pendingChange, isNull);
    expect(remote.writes, 1);
  });

  test(
    'a delayed profile request is checked before another save is sent',
    () async {
      service = ProfileService(
        remote,
        local: local,
        store: store,
        requestTimeout: const Duration(milliseconds: 50),
      );
      remote.profileGate = Completer<void>();
      final saving = expectLater(
        service.updateProfile('Juan', 'juan@example.com'),
        throwsA(isA<ConnectionFailure>()),
      );
      await remote.profileReceived.future;
      await saving;
      await expectLater(
        service.updateProfile('Juan', 'juan@example.com'),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(remote.writes, 1);

      remote.profileGate!.complete();
      await service.getProfile();
      await service.updateProfile('Juan', 'juan@example.com');
      expect(remote.writes, 1);
      expect(service.pendingChange, isNull);
    },
  );

  test(
    'adding a vehicle with a lost response is not repeated after reopening',
    () async {
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(
        service.addVehicle(VehicleType.car, 'ABC123'),
        throwsA(isA<ConnectionFailure>()),
      );
      expect(service.pendingChange?['kind'], 'add_vehicle');
      remote.online = true;
      final reopened = ProfileService(
        remote,
        local: local,
        store: UserLocalStore(client, getDirectory: () async => directory),
      );

      await reopened.addVehicle(VehicleType.car, 'ABC123');

      expect(remote.writes, 1);
      expect(remote.vehicles.length, 1);
      expect(reopened.pendingChange, isNull);
    },
  );

  test(
    'select and delete can recover their server result without replaying',
    () async {
      await remote.addVehicle(VehicleType.car, 'ABC123');
      await remote.addVehicle(VehicleType.motorcycle, 'ABC12D');
      remote.writes = 0;
      remote.loseReply = true;
      await service.selectVehicle('vehicle-2');
      expect(
        remote.vehicles.singleWhere((vehicle) => vehicle.isSelected).id,
        'vehicle-2',
      );
      remote.loseReply = true;
      await service.deleteVehicle('vehicle-1');

      expect(remote.writes, 2);
      expect(remote.vehicles.single.id, 'vehicle-2');
      expect(service.pendingChange, isNull);
    },
  );

  test(
    'refresh checks an unconfirmed vehicle change without sending it again',
    () async {
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(
        service.addVehicle(VehicleType.car, 'ABC123'),
        throwsA(isA<ConnectionFailure>()),
      );
      remote.online = true;
      final controller = ProfileController(service);
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.vehicles.single.plate, 'ABC123');
      expect(controller.pendingChange, isNull);
      expect(remote.writes, 1);
    },
  );

  test('another change cannot replace an unconfirmed request', () async {
    remote.loseReply = true;
    remote.disconnectAfterWrite = true;
    await expectLater(
      service.addVehicle(VehicleType.car, 'ABC123'),
      throwsA(isA<ConnectionFailure>()),
    );
    await expectLater(
      service.addVehicle(VehicleType.car, 'XYZ987'),
      throwsA(isA<ConnectionFailure>()),
    );

    expect((await store.read('profile_request'))?['plate'], 'ABC123');
    expect((await store.read('draft_add_vehicle'))?['plate'], 'ABC123');
    expect(remote.writes, 1);
  });

  test('quick draft writes keep the last choice and remain private after reopening', () async {
    await Future.wait([
      store.write('pickup', {'time': '15:00'}),
      store.write('pickup', {'time': '15:30'}),
      store.write('pickup', {'time': '16:00'}),
    ]);
    final reopened = UserLocalStore(
      client,
      getDirectory: () async => directory,
    );
    expect((await reopened.read('pickup'))?['time'], '16:00');
    await signInAs(client, 'user-2');
    expect(await reopened.read('pickup'), isNull);
  });
}
