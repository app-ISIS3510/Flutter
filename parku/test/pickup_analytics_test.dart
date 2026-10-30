import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/repositories/analytics_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/pickup_analytics_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart';
import 'support/memory_auth_storage.dart';

class PickupEvents extends AnalyticsRepository {
  bool online = true;
  bool loseReply = false;
  int attempts = 0;
  Completer<void>? gate;
  final received = Completer<void>();
  final saved = <String, Map<String, dynamic>>{};

  PickupEvents(super.client);

  @override
  Future<void> savePickupChoice(Map<String, dynamic> event) async {
    attempts++;
    if (!received.isCompleted) received.complete();
    if (!online) throw const SocketException('Offline');
    await gate?.future;
    if (userId != event['user_id']) {
      throw const AuthException('Account changed');
    }
    saved.putIfAbsent(event['id'] as String, () => event);
    if (loseReply) {
      loseReply = false;
      throw const SocketException('Response lost');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SupabaseClient client;
  late PickupEvents remote;
  late UserLocalStore store;
  late PickupAnalyticsService analytics;
  final suggested = DateTime.utc(2026, 10, 26, 22);

  ParkingSession session(String id) => ParkingSession(
    id: id,
    userId: 'user-1',
    parkingId: 'parking-1',
    pickupTime: suggested,
    startedAt: DateTime.utc(2026, 10, 26, 20),
    status: 'active',
    vehicleId: 'vehicle-1',
    vehiclePlate: 'ABC123',
  );

  Map<String, dynamic> choice({bool manual = false}) => {
    'pickup_time':
        (manual ? suggested.add(const Duration(hours: 1)) : suggested)
            .toIso8601String(),
    'suggested_pickup_time': suggested.toIso8601String(),
  };

  PickupAnalyticsService reopen() => PickupAnalyticsService(
    remote,
    UserLocalStore(client, getDirectory: () async => directory),
    timeout: const Duration(milliseconds: 100),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-pickup-bq-');
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    remote = PickupEvents(client);
    store = UserLocalStore(client, getDirectory: () async => directory);
    analytics = reopen();
  });

  tearDown(() async {
    await analytics.flush();
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test('records the selected source and the server start time without plate or email', () async {
    await analytics.saveChoice(session('session-1'), choice());
    await analytics.flush();
    await analytics.saveChoice(session('session-2'), choice(manual: true));
    await analytics.flush();

    expect(
      remote.saved['session-1']!['metadata']['pickup_selection'],
      'suggested',
    );
    expect(
      remote.saved['session-2']!['metadata']['pickup_selection'],
      'manual',
    );
    expect(
      remote.saved['session-1']!['created_at'],
      '2026-10-26T20:00:00.000Z',
    );
    expect(remote.saved['session-1']!['event_type'], 'parking_pickup_choice');
    expect(remote.saved.toString(), isNot(contains('ABC123')));
    expect(remote.saved.toString(), isNot(contains('@')));
  });

  test(
    'offline events survive reopening and are removed only after delivery',
    () async {
      remote.online = false;
      await analytics.saveChoice(session('session-1'), choice());
      expect(await analytics.flush(), isFalse);
      expect((await store.read('pickup_analytics'))!['events'], hasLength(1));

      analytics = reopen();
      remote.online = true;
      expect(await analytics.flush(), isTrue);
      expect(remote.saved, hasLength(1));
      expect((await store.read('pickup_analytics'))!['events'], isEmpty);
    },
  );

  test(
    'a lost analytics response retries the same event without a second row',
    () async {
      remote.loseReply = true;
      await analytics.saveChoice(session('session-1'), choice());
      expect(await analytics.flush(), isFalse);
      expect(remote.saved, hasLength(1));
      expect(await analytics.flush(), isTrue);
      expect(remote.attempts, 2);
      expect(remote.saved, hasLength(1));
    },
  );

  test('saving a choice does not wait for the network and concurrent flushes share work', () async {
    remote.gate = Completer<void>();
    await analytics.saveChoice(session('session-1'), choice());
    await remote.received.future;
    final sending = analytics.flush();
    expect(identical(sending, analytics.flush()), isTrue);

    await analytics.saveChoice(session('session-2'), choice(manual: true));
    expect((await store.read('pickup_analytics'))!['events'], hasLength(2));
    remote.gate!.complete();
    expect(await sending, isTrue);
    expect(remote.saved, hasLength(2));
    expect(remote.attempts, 2);
  });

  test('switching accounts keeps the original queue private until its owner returns', () async {
    remote.online = false;
    await analytics.saveChoice(session('session-1'), choice());
    await analytics.flush();
    await signInAs(client, 'user-2');
    expect(await store.read('pickup_analytics'), isNull);
    await analytics.saveChoice(session('session-2'), choice());
    remote.online = true;
    expect(await analytics.flush(), isTrue);
    expect(remote.saved, isEmpty);

    await signInAs(client, 'user-1');
    expect(await analytics.flush(), isTrue);
    expect(remote.saved.keys, ['session-1']);
  });

  test(
    'the new account sends its queue after an earlier account finishes sending',
    () async {
      remote.gate = Completer<void>();
      await analytics.saveChoice(session('session-1'), choice());
      await remote.received.future;
      await signInAs(client, 'user-2');
      final nextSession = ParkingSession.fromMap({
        ...session('session-2').toMap(),
        'user_id': 'user-2',
      });
      await analytics.saveChoice(nextSession, choice(manual: true));
      final sending = analytics.flush();
      remote.gate!.complete();

      expect(await sending, isTrue);
      expect(remote.saved.keys, ['session-2']);
      expect((await store.read('pickup_analytics'))!['events'], isEmpty);

      await signInAs(client, 'user-1');
      expect(await analytics.flush(), isTrue);
      expect(remote.saved.keys, ['session-2', 'session-1']);
    },
  );

  test(
    'old requests without the original suggestion are left unrecorded',
    () async {
      await analytics.saveChoice(session('session-1'), {
        'pickup_time': suggested.toIso8601String(),
      });
      await analytics.flush();
      expect(remote.saved, isEmpty);
      expect(await store.read('pickup_analytics'), isNull);
    },
  );

  test(
    'an unsuccessful parking start never records a successful choice',
    () async {
      final sessions = UnstableSessionRepository(client)..online = false;
      final service = SessionService(
        sessions,
        store: store,
        pickupAnalytics: analytics,
      );
      await expectLater(
        service.startParking(
          parkingId: 'parking-1',
          vehicleId: 'vehicle-1',
          pickupTime: suggested,
          suggestedPickupTime: suggested,
        ),
        throwsA(isA<SocketException>()),
      );
      await analytics.flush();
      expect(remote.saved, isEmpty);
      expect(sessions.starts, 0);
    },
  );

  test('an uncertain parking start is recorded once after recovery with its original suggestion', () async {
    final sessions = UnstableSessionRepository(client)
      ..loseReply = true
      ..disconnectAfterWrite = true;
    var service = SessionService(
      sessions,
      store: store,
      pickupAnalytics: analytics,
    );
    await expectLater(
      service.startParking(
        parkingId: 'parking-1',
        vehicleId: 'vehicle-1',
        pickupTime: suggested,
        suggestedPickupTime: suggested,
      ),
      throwsA(isA<ConnectionFailure>()),
    );
    expect(remote.saved, isEmpty);

    sessions.online = true;
    service = SessionService(
      sessions,
      store: store,
      pickupAnalytics: analytics,
    );
    await service.startParking(
      parkingId: 'parking-1',
      vehicleId: 'vehicle-1',
      pickupTime: suggested,
      suggestedPickupTime: suggested.add(const Duration(hours: 1)),
    );
    await analytics.flush();
    expect(sessions.starts, 1);
    expect(remote.saved, hasLength(1));
    expect(
      remote.saved.values.single['metadata']['pickup_selection'],
      'suggested',
    );
    expect(await store.read('session_request'), isNull);
  });

  test('the real repository sends an insert with a stable ID and ignores duplicate IDs', () async {
    final requests = <http.Request>[];
    final api = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('', 201, request: request);
      }),
    );
    await signInAs(api, 'user-1');
    final repository = AnalyticsRepository(api);
    await repository.savePickupChoice({
      'id': 'session-1',
      'user_id': 'user-1',
      'event_type': 'parking_pickup_choice',
    });
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/analytics_events');
    expect(request.url.queryParameters['on_conflict'], 'id');
    expect(request.headers['Prefer'], contains('resolution=ignore-duplicates'));
    expect(jsonDecode(request.body)['id'], 'session-1');
    await expectLater(
      repository.savePickupChoice({'id': 'session-2', 'user_id': 'user-2'}),
      throwsA(isA<AuthException>()),
    );
    expect(requests, hasLength(1));
    await api.dispose();
  });
}
