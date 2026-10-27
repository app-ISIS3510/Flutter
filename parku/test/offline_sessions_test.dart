import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/session_controller.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/repositories/session_history_repository.dart';
import 'package:parku/repositories/personal_data_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/state/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/offline_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SupabaseClient client;
  late UnstableSessionRepository remote;
  late UserLocalStore store;
  late SessionHistoryRepository history;
  late SessionService service;
  late PersonalDataRepository local;
  final pickup = DateTime.utc(2026, 10, 26, 22);

  SessionService reopen() => SessionService(
    remote,
    store: UserLocalStore(client, getDirectory: () async => directory),
    local: local,
    historyRepository: history,
    requestTimeout: const Duration(milliseconds: 50),
  );

  Future<ParkingSession> start() => service.startParking(
    parkingId: 'parking-1',
    vehicleId: 'vehicle-1',
    pickupTime: pickup,
    parkingName: 'City U Parking',
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-offline-session-');
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    remote = UnstableSessionRepository(client);
    local = PersonalDataRepository(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/personal.db',
    );
    store = UserLocalStore(client, getDirectory: () async => directory);
    history = SessionHistoryRepository(
      client,
      getDirectory: () async => directory,
    );
    service = reopen();
  });
  tearDown(() async {
    await local.close();
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'starting without internet keeps the selection and never creates a session',
    () async {
      await service.savePickupDraft('start_parking-1', {
        'time': '17:00',
        'vehicle_id': 'vehicle-1',
      });
      remote.online = false;
      await expectLater(start(), throwsA(isA<SocketException>()));

      expect(remote.starts, 0);
      expect(
        (await reopen().getPickupDraft('start_parking-1'))?['time'],
        '17:00',
      );
    },
  );

  test(
    'a lost start response is verified instead of creating another session',
    () async {
      remote.loseReply = true;
      final session = await start();

      expect(session.status, 'active');
      expect(remote.starts, 1);
      expect(service.recoveredRequest, isTrue);
      expect(service.pendingRequest, isNull);
    },
  );

  test(
    'an unconfirmed start survives reopening and is checked before retrying',
    () async {
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(start(), throwsA(isA<ConnectionFailure>()));
      expect((await store.read('session_request'))?['kind'], 'start');
      remote.online = true;
      service = reopen();
      final session = await start();

      expect(session.id, 'session-1');
      expect(remote.starts, 1);
      expect(await store.read('session_request'), isNull);
    },
  );

  test('an old completed stay with the same pickup time is not mistaken for a new one', () async {
    remote.sessions.add(
      ParkingSession(
        id: 'old-session',
        userId: 'user-1',
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: pickup,
        startedAt: pickup.subtract(const Duration(hours: 2)),
        endedAt: pickup.subtract(const Duration(hours: 1)),
        status: 'completed',
      ),
    );
    remote.loseReply = true;
    final session = await start();

    expect(session.id, 'session-1');
    expect(session.status, 'active');
    expect(remote.sessions.length, 2);
  });

  test(
    'an unresolved timed-out request is not sent twice while still running',
    () async {
      remote.startGate = Completer<void>();
      await expectLater(start(), throwsA(isA<ConnectionFailure>()));
      await expectLater(start(), throwsA(isA<ConnectionFailure>()));
      expect(remote.starts, 1);

      remote.startGate!.complete();
      await Future<void>.delayed(Duration.zero);
      final recovered = await service.getActiveSession();

      expect(recovered?.status, 'active');
      expect(remote.starts, 1);
    },
  );

  test(
    'confirmed session data remains available offline after reopening',
    () async {
      final confirmed = await start();
      await local.close();
      remote.online = false;
      service = reopen();

      expect((await service.getActiveSession())?.id, confirmed.id);
      expect(service.usingSavedSession, isTrue);
      await signInAs(client, 'user-2');
      await expectLater(
        service.getActiveSession(),
        throwsA(isA<ConnectionFailure>()),
      );
    },
  );

  test('a stalled read uses the saved session after its deadline', () async {
    final confirmed = await start();
    remote.activeReply = Completer<ParkingSession?>();
    expect((await service.getActiveSession())?.id, confirmed.id);
    expect(service.usingSavedSession, isTrue);
    remote.activeReply!.complete(null);
  });

  test(
    'an offline pickup-time change keeps the draft and the confirmed time',
    () async {
      final confirmed = await start();
      final state = SessionState()..setActiveSession(confirmed);
      addTearDown(state.dispose);
      final controller = SessionController(service, state);
      await service.savePickupDraft('change_${confirmed.id}', {
        'time': '18:00',
      });
      remote.online = false;

      await expectLater(
        controller.changePickupTime(
          sessionId: confirmed.id,
          pickupTime: pickup.add(const Duration(hours: 1)),
        ),
        throwsA(isA<SocketException>()),
      );

      expect(state.activeSession?.pickupTime, pickup);
      expect(remote.changes, 0);
      expect(
        (await reopen().getPickupDraft('change_${confirmed.id}'))?['time'],
        '18:00',
      );
    },
  );

  test(
    'a lost pickup-time response is recovered without another update',
    () async {
      final confirmed = await start();
      final requested = pickup.add(const Duration(hours: 1));
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(
        service.changePickupTime(
          sessionId: confirmed.id,
          pickupTime: requested,
        ),
        throwsA(isA<ConnectionFailure>()),
      );
      remote.online = true;
      service = reopen();
      final recovered = await service.changePickupTime(
        sessionId: confirmed.id,
        pickupTime: requested,
      );

      expect(recovered.pickupTime, requested);
      expect(remote.changes, 1);
    },
  );

  test(
    'a lost end response is recovered and the summary is saved once',
    () async {
      final confirmed = await start();
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(
        service.endParking(
          sessionId: confirmed.id,
          parkingName: 'City U Parking',
        ),
        throwsA(isA<ConnectionFailure>()),
      );
      final endedAt = remote.sessions.single.endedAt;
      remote.online = true;
      service = reopen();

      final ended = await service.endParking(
        sessionId: confirmed.id,
        parkingName: 'City U Parking',
      );
      await service.endParking(
        sessionId: confirmed.id,
        parkingName: 'City U Parking',
      );

      expect(ended.status, 'completed');
      expect(ended.endedAt, endedAt);
      expect(remote.ends, 1);
      expect(
        (await history.getSavedSessions()).single.parkingName,
        'City U Parking',
      );
    },
  );

  test(
    'an offline end keeps the active session and sends no end mutation',
    () async {
      final confirmed = await start();
      final state = SessionState()..setActiveSession(confirmed);
      addTearDown(state.dispose);
      final controller = SessionController(service, state);
      remote.online = false;

      await expectLater(
        controller.endParking(sessionId: confirmed.id),
        throwsA(isA<SocketException>()),
      );

      expect(state.activeSession?.id, confirmed.id);
      expect(remote.ends, 0);
      expect(await history.getSavedSessions(), isEmpty);
    },
  );

  test(
    'a different mutation first resolves the previous uncertain result',
    () async {
      final confirmed = await start();
      remote.loseReply = true;
      remote.disconnectAfterWrite = true;
      await expectLater(
        service.changePickupTime(
          sessionId: confirmed.id,
          pickupTime: pickup.add(const Duration(hours: 1)),
        ),
        throwsA(isA<ConnectionFailure>()),
      );
      remote.online = true;

      await expectLater(
        service.endParking(sessionId: confirmed.id),
        throwsA(isA<ConnectionFailure>()),
      );

      expect(remote.ends, 0);
      expect(service.pendingRequest, isNull);
      await service.endParking(sessionId: confirmed.id);
      expect(remote.ends, 1);
    },
  );

  test('an ended session cannot have its pickup time changed', () async {
    final confirmed = await start();
    await service.endParking(sessionId: confirmed.id);
    await expectLater(
      service.changePickupTime(
        sessionId: confirmed.id,
        pickupTime: pickup.add(const Duration(hours: 1)),
      ),
      throwsA(isA<ConnectionFailure>()),
    );
    expect(remote.changes, 0);
  });

  test('refresh resolves an uncertain time change even if the session ended elsewhere', () async {
    final confirmed = await start();
    remote.loseReply = true;
    remote.disconnectAfterWrite = true;
    await expectLater(
      service.changePickupTime(
        sessionId: confirmed.id,
        pickupTime: pickup.add(const Duration(hours: 1)),
        parkingName: 'City U Parking',
      ),
      throwsA(isA<ConnectionFailure>()),
    );
    remote.online = true;
    await remote.endSession(sessionId: confirmed.id);

    expect(await service.getActiveSession(), isNull);
    expect(service.pendingRequest, isNull);
    expect(
      (await history.getSavedSessions()).single.parkingName,
      'City U Parking',
    );
  });

  test('a late response from the previous account cannot update the new session state', () async {
    final state = SessionState();
    addTearDown(state.dispose);
    final controller = SessionController(service, state);
    remote.startGate = Completer<void>();
    final starting = controller.startParking(
      parkingId: 'parking-1',
      vehicleId: 'vehicle-1',
      pickupTime: pickup,
    );
    final rejected = expectLater(starting, throwsA(isA<AuthException>()));
    await remote.startReceived.future;
    await signInAs(client, 'user-2');
    controller.clear();
    remote.startGate!.complete();
    await rejected;

    expect(state.activeSession, isNull);
    expect(await store.read('active_session'), isNull);
  });
}
