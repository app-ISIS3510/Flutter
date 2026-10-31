import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/pickup_choice_summary.dart';
import 'package:parku/repositories/analytics_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/pickup_analytics_service.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart' show signInAs;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SupabaseClient client;
  late PickupAnalyticsService service;
  final requests = <http.Request>[];
  var online = true;
  var denied = false;
  Completer<void>? responseGate;
  late Completer<void> received;
  late List<Map<String, dynamic>> rows;

  List<Map<String, dynamic>> results(
    int suggested,
    int manual,
    int unknown,
  ) => [
    for (final entry in {
      'Suggested': suggested,
      'Manual': manual,
      'Not recorded': unknown,
    }.entries)
      {
        'pickup_choice': entry.key,
        'successful_starts': entry.value,
        'percentage': suggested + manual + unknown == 0
            ? 0
            : (entry.value * 10000 / (suggested + manual + unknown)).round() /
                  100,
        'total_successful_starts': suggested + manual + unknown,
      },
  ];

  UserLocalStore store() =>
      UserLocalStore(client, getDirectory: () async => directory);

  PickupAnalyticsService reopen({
    Duration timeout = const Duration(milliseconds: 500),
  }) => PickupAnalyticsService(
    AnalyticsRepository(client),
    store(),
    timeout: timeout,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-pickup-summary-');
    requests.clear();
    online = true;
    denied = false;
    responseGate = null;
    received = Completer<void>();
    rows = results(2, 1, 1);
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (!received.isCompleted) received.complete();
        if (!online) throw const SocketException('Offline');
        await responseGate?.future;
        return http.Response(
          jsonEncode(
            denied ? {'code': '42501', 'message': 'Permission denied'} : rows,
          ),
          denied ? 403 : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signInAs(client, 'user-1');
    service = reopen();
  });

  tearDown(() async {
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'a normal account reads the shared view and counts unrecorded starts',
    () async {
      final summary = await service.loadSummary();
      expect(client.auth.currentUser!.appMetadata, isEmpty);
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.path,
        '/rest/v1/bq9_pickup_time_choice_last_7_days',
      );
      expect(summary.total, 4);
      expect(summary.suggestedPercentage, 50);
      expect(summary.manualPercentage, 25);
      expect(summary.notRecordedPercentage, 25);
      expect(summary.isFromCache, isFalse);
      final saved = (await store().read('pickup_choice_summary'))!;
      expect(saved.keys.toSet(), {
        'suggested',
        'manual',
        'not_recorded',
        'updated_at',
        'suggested_percentage',
        'manual_percentage',
        'not_recorded_percentage',
      });
    },
  );

  test(
    'the last result and its date survive reopening without internet',
    () async {
      final live = await service.loadSummary();
      online = false;
      final saved = await reopen().loadSummary();
      expect(saved.isFromCache, isTrue);
      expect(saved.total, live.total);
      expect(saved.updatedAt, live.updatedAt);
    },
  );

  test(
    'a first offline visit reports failure instead of inventing percentages',
    () async {
      online = false;
      await expectLater(
        service.loadSummary(),
        throwsA(predicate(isConnectionError)),
      );
    },
  );

  test('an account cannot read another account cache', () async {
    await service.loadSummary();
    await signInAs(client, 'user-2');
    online = false;
    await expectLater(
      service.loadSummary(),
      throwsA(predicate(isConnectionError)),
    );
    await signInAs(client, 'user-1');
    expect((await service.loadSummary()).total, 4);
  });

  test('a late result cannot be saved under a different account', () async {
    responseGate = Completer<void>();
    final loading = service.loadSummary();
    await received.future;
    await signInAs(client, 'user-2');
    final failure = expectLater(loading, throwsA(isA<AuthException>()));
    responseGate!.complete();
    await failure;
    expect(await store().read('pickup_choice_summary'), isNull);
    await signInAs(client, 'user-1');
    expect(await store().read('pickup_choice_summary'), isNull);
  });

  test(
    'a timeout returns the saved result while a request is still waiting',
    () async {
      await service.loadSummary();
      responseGate = Completer<void>();
      final cached = await reopen(timeout: const Duration(milliseconds: 100))
          .loadSummary();
      expect(cached.isFromCache, isTrue);
      responseGate!.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('permission errors are not presented as a connection failure', () async {
    await service.loadSummary();
    denied = true;
    await expectLater(
      service.loadSummary(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'refresh replaces the cached result without mixing in pending events',
    () async {
      await service.loadSummary();
      rows = results(1, 5, 2);
      expect((await service.loadSummary()).total, 8);
      online = false;
      final cached = await reopen().loadSummary();
      expect(cached.suggested, 1);
      expect(cached.manual, 5);
      expect(cached.notRecorded, 2);
    },
  );

  test('an empty week has no invalid percentages', () async {
    rows = results(0, 0, 0);
    final summary = await service.loadSummary();
    expect(summary.total, 0);
    expect(summary.suggestedPercentage, 0);
  });

  test('invalid results cannot overwrite a valid saved summary', () async {
    await service.loadSummary();
    rows[0]['total_successful_starts'] = 9;
    await expectLater(service.loadSummary(), throwsA(isA<FormatException>()));
    online = false;
    expect((await service.loadSummary()).total, 4);
  });

  test(
    'the repository needs a signed-in account before making a request',
    () async {
      final guest = SupabaseClient('https://test.invalid', 'test-key');
      try {
        await expectLater(
          AnalyticsRepository(guest).getPickupChoices(),
          throwsA(isA<AuthException>()),
        );
      } finally {
        await guest.dispose();
      }
    },
  );

  test(
    'the app keeps the percentages already rounded by the database',
    () async {
      rows = results(199, 1000, 2801);
      rows[0]['percentage'] = 4.98;
      expect((await service.loadSummary()).suggestedPercentage, 4.98);
      online = false;
      expect((await service.loadSummary()).suggestedPercentage, 4.98);
    },
  );

  test('negative category counts are rejected', () {
    expect(
      () => PickupChoiceSummary.fromRows(
        results(-1, 3, 2),
        updatedAt: DateTime.now(),
      ),
      throwsFormatException,
    );
  });

  test('invalid saved percentages are not shown offline', () async {
    final summary = await service.loadSummary();
    await store().write('pickup_choice_summary', {
      ...summary.toMap(),
      'suggested_percentage': 101,
    });
    online = false;
    await expectLater(service.loadSummary(), throwsA(isA<FormatException>()));
  });
}
