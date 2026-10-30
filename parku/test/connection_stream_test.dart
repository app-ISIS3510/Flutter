import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/connection_controller.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/controllers/session_controller.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/state/session_state.dart';

import 'support/offline_fakes.dart';

Future<void> settleEvents() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StreamController<List<ConnectivityResult>> events;
  late ConnectionController controller;
  var refreshes = 0;
  var available = false;

  ConnectionController create(Future<void> Function() refresh) {
    return ConnectionController(
      onReconnect: refresh,
      changes: events.stream,
      checkConnection: () async => [
        available ? ConnectivityResult.wifi : ConnectivityResult.none,
      ],
      delay: Duration.zero,
    );
  }

  setUp(() {
    events = StreamController<List<ConnectivityResult>>.broadcast();
    refreshes = 0;
    available = false;
    controller = create(() async => refreshes++);
  });
  tearDown(() async {
    controller.dispose();
    await events.close();
  });

  test(
    'a stream reconnect refreshes once and ignores repeated network reports',
    () async {
      await controller.start();
      await settleEvents();
      expect(refreshes, 0);
      events.add([ConnectivityResult.wifi]);
      events.add([ConnectivityResult.wifi]);
      events.add([ConnectivityResult.mobile]);
      await settleEvents();
      expect(refreshes, 1);
      events.add([ConnectivityResult.none]);
      events.add([ConnectivityResult.ethernet]);
      await settleEvents();
      expect(refreshes, 2);
    },
  );

  test(
    'a new reconnect waits for the current check instead of overlapping it',
    () async {
      controller.dispose();
      final gate = Completer<void>();
      var running = 0;
      var maximumRunning = 0;
      controller = create(() async {
        refreshes++;
        running++;
        if (running > maximumRunning) maximumRunning = running;
        if (refreshes == 1) await gate.future;
        running--;
      });
      await controller.start();
      events.add([ConnectivityResult.wifi]);
      await settleEvents();
      events.add([ConnectivityResult.none]);
      events.add([ConnectivityResult.wifi]);
      events.add([ConnectivityResult.none]);
      events.add([ConnectivityResult.wifi]);
      await settleEvents();
      expect(refreshes, 1);
      gate.complete();
      await settleEvents();
      expect(refreshes, 2);
      expect(maximumRunning, 1);
    },
  );

  test(
    'moving from failed Wi-Fi to mobile data retries synchronization',
    () async {
      controller.dispose();
      var serverAvailable = false;
      controller = create(() async {
        refreshes++;
        if (!serverAvailable) throw const SocketException('No internet');
      });
      await controller.start();
      events.add([ConnectivityResult.wifi]);
      await settleEvents();
      expect(controller.error, isNotNull);

      serverAvailable = true;
      events.add([ConnectivityResult.mobile]);
      await settleEvents();
      expect(refreshes, 2);
      expect(controller.error, isNull);
      events.add([ConnectivityResult.mobile]);
      await settleEvents();
      expect(refreshes, 2);
    },
  );

  test(
    'Wi-Fi without server access is not reported as a successful refresh',
    () async {
      controller.dispose();
      var serverAvailable = false;
      controller = create(() async {
        refreshes++;
        if (!serverAvailable) throw const SocketException('No internet');
      });
      await controller.start();
      events.add([ConnectivityResult.wifi]);
      await settleEvents();
      expect(controller.hasNetwork, isTrue);
      expect(controller.notice, contains('Could not reach the server'));
      serverAvailable = true;
      available = true;
      await controller.recheck(refresh: true);
      await settleEvents();
      expect(refreshes, 2);
      expect(controller.notice, isNull);
    },
  );

  test(
    'rechecking on resume recovers changes missed in the background',
    () async {
      await controller.start();
      available = true;
      await controller.recheck(refresh: true);
      await settleEvents();
      expect(refreshes, 1);
      await controller.recheck(refresh: true);
      await settleEvents();
      expect(refreshes, 2);
    },
  );

  test('an old initial result cannot replace a newer stream event', () async {
    controller.dispose();
    final initial = Completer<List<ConnectivityResult>>();
    controller = ConnectionController(
      onReconnect: () async => refreshes++,
      changes: events.stream,
      checkConnection: () => initial.future,
      delay: Duration.zero,
    );
    final starting = controller.start();
    events.add([ConnectivityResult.wifi]);
    await settleEvents();
    initial.complete([ConnectivityResult.none]);
    await starting;
    expect(controller.hasNetwork, isTrue);
    expect(refreshes, 1);
  });

  test('disposing stops the subscription and prevents queued work', () async {
    controller.dispose();
    controller = ConnectionController(
      onReconnect: () async => refreshes++,
      changes: events.stream,
      checkConnection: () async => [ConnectivityResult.none],
      delay: const Duration(milliseconds: 20),
    );
    await controller.start();
    events.add([ConnectivityResult.wifi]);
    await settleEvents();
    controller.dispose();
    expect(events.hasListener, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(refreshes, 0);
    controller = create(() async {});
  });

  test('a stream error preserves manual recovery', () async {
    await controller.start();
    events.addError(StateError('Platform unavailable'));
    await settleEvents();
    expect(controller.notice, contains('refresh manually'));
    available = true;
    await controller.recheck(refresh: true);
    await settleEvents();
    expect(refreshes, 1);
    expect(controller.error, isNull);
  });

  test(
    'closing the screen stops waiting for an unfinished connection check',
    () async {
      controller.dispose();
      final read = Completer<List<ConnectivityResult>>();
      controller = ConnectionController(
        onReconnect: () async => refreshes++,
        changes: events.stream,
        checkConnection: () => read.future,
      );
      final starting = controller.start();
      controller.dispose();
      await starting;
      read.complete([ConnectivityResult.wifi]);
      await settleEvents();
      expect(refreshes, 0);
      controller = create(() async {});
    },
  );

  test('reconnection verifies lost parking and vehicle responses without replaying writes', () async {
    final client = offlineTestClient();
    await signInAs(client, 'user-1');
    addTearDown(client.dispose);
    final local = UserLocalStore.memory(client);
    final sessions = UnstableSessionRepository(client);
    final service = SessionService(sessions, store: local);
    final state = SessionState();
    final sessionController = SessionController(service, state);
    addTearDown(state.dispose);
    addTearDown(sessionController.dispose);
    sessions.loseReply = true;
    sessions.disconnectAfterWrite = true;
    await expectLater(
      sessionController.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: DateTime.now().add(const Duration(hours: 2)),
      ),
      throwsA(isA<ConnectionFailure>()),
    );
    final users = UnstableUserRepository()
      ..loseReply = true
      ..disconnectAfterWrite = true;
    final profile = ProfileController(ProfileService(users, store: local));
    addTearDown(profile.dispose);
    expect(await profile.addVehicle(VehicleType.car, 'ABC123'), isFalse);
    controller.dispose();
    controller = create(() async {
      await profile.load();
      await sessionController.loadActiveSession();
    });
    await controller.start();
    sessions.online = true;
    users.online = true;
    events.add([ConnectivityResult.wifi]);
    await settleEvents();
    expect(state.activeSession?.id, 'session-1');
    expect(profile.vehicles.single.plate, 'ABC123');
    expect(service.pendingRequest, isNull);
    expect(profile.pendingChange, isNull);
    expect(sessions.starts, 1);
    expect(users.writes, 1);
  });

  testWidgets(
    'the interface stays usable while a reconnect check waits for the server',
    (tester) async {
      controller.dispose();
      await events.close();
      events = StreamController<List<ConnectivityResult>>.broadcast();
      final response = Completer<void>();
      controller = create(() => response.future);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, child) => Column(
                children: [
                  Text(controller.checking ? 'Checking parking' : 'My parking'),
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('Open profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await controller.start();
      events.add([ConnectivityResult.wifi]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Checking parking'), findsOneWidget);
      await tester.tap(find.text('Open profile'));
      expect(taps, 1);
      response.complete();
      await tester.pumpAndSettle();
      expect(find.text('My parking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('automatic and manual session checks share the same request', () async {
    final client = offlineTestClient();
    await signInAs(client, 'user-1');
    addTearDown(client.dispose);
    final remote = UnstableSessionRepository(client);
    final service = SessionService(
      remote,
      store: UserLocalStore.memory(client),
    );
    final confirmed = await service.startParking(
      parkingId: 'parking-1',
      vehicleId: 'vehicle-1',
      pickupTime: DateTime.now().add(const Duration(hours: 2)),
    );
    remote.activeReads = 0;
    remote.activeReply = Completer();
    final state = SessionState();
    final sessions = SessionController(service, state);
    addTearDown(sessions.dispose);
    addTearDown(state.dispose);
    final first = sessions.loadActiveSession();
    final second = sessions.loadActiveSession();
    await settleEvents();
    expect(remote.activeReads, 1);
    remote.activeReply!.complete(confirmed);
    await Future.wait([first, second]);
    expect(state.activeSession?.id, confirmed.id);
  });

  test(
    'a late read cannot restore an already ended session in the offline cache',
    () async {
      final client = offlineTestClient();
      await signInAs(client, 'user-1');
      addTearDown(client.dispose);
      final remote = UnstableSessionRepository(client);
      final service = SessionService(
        remote,
        store: UserLocalStore.memory(client),
      );
      final active = await service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: DateTime.now().add(const Duration(hours: 2)),
      );
      remote.activeReply = Completer();
      final read = service.getActiveSession();
      await settleEvents();
      await service.endParking(sessionId: active.id);
      remote.activeReply!.complete(active);
      await read;
      remote.online = false;
      remote.activeReply = null;
      await expectLater(
        service.getActiveSession(),
        throwsA(isA<ConnectionFailure>()),
      );
    },
  );
}
