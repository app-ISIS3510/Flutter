import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/repositories/analytics_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/analytics_queue.dart';
import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart' show signInAs;

void main() {
  late SupabaseClient client;
  late TestAnalyticsQueue queue;
  late AnalyticsRepository repository;

  bool online = true;
  final requests = <http.Request>[];

  setUp(() async {
    online = true;
    requests.clear();
    queue = TestAnalyticsQueue();

    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);

        if (!online) {
          throw const SocketException('Offline');
        }

        return http.Response('', 201, request: request);
      }),
    );

    await signInAs(client, 'user-1');

    repository = AnalyticsRepository(client, localDataSource: queue);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('stores analytics events locally before synchronization', () async {
    await repository.trackEvent(
      eventType: 'parking_search',
      screen: 'search_results',
      metadata: {'query': 'city'},
    );

    final pending = await queue.readDue('user-1');

    expect(pending, hasLength(1));
    expect(pending.single.eventType, 'parking_search');
    expect(pending.single.screen, 'search_results');
    expect(pending.single.metadata['query'], 'city');
    expect(requests, isEmpty);
  });

  test('synchronizes pending events and removes them from queue', () async {
    await repository.trackEvent(
      eventType: 'parking_details_opened',
      parkingId: 'parking-1',
    );

    final pending = await queue.readDue('user-1');
    final originalId = pending.single.id;

    await repository.flushPending();

    expect(await queue.readDue('user-1'), isEmpty);
    expect(requests, hasLength(1));

    final request = requests.single;
    final payload = jsonDecode(request.body) as Map<String, dynamic>;

    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/analytics_events');
    expect(request.url.queryParameters['on_conflict'], 'id');
    expect(request.headers['Prefer'], contains('resolution=ignore-duplicates'));
    expect(payload['id'], originalId);
    expect(payload['event_type'], 'parking_details_opened');
    expect(payload['parking_id'], 'parking-1');
  });

  test('keeps failed events for a later retry', () async {
    await repository.trackEvent(
      eventType: 'parking_search',
      screen: 'search_results',
    );

    final originalId = (await queue.readDue('user-1')).single.id;

    online = false;

    await repository.flushPending();

    expect(queue.events, hasLength(1));
    expect(queue.events.single.id, originalId);

    // The failed event remains in storage, but its next retry
    // is scheduled in the future.
    expect(await queue.readDue('user-1'), isEmpty);

    online = true;
    await repository.flushPending();

    // It must not retry before its scheduled time.
    expect(queue.events, hasLength(1));
    expect(requests, isNotEmpty);
  });

  test('does not synchronize events belonging to another user', () async {
    await repository.trackEvent(
      eventType: 'parking_search',
      screen: 'search_results',
    );

    final originalEvent = (await queue.readDue('user-1')).single;

    await signInAs(client, 'user-2');

    await repository.flushPending();

    expect(requests, isEmpty);
    expect(await queue.readDue('user-1'), hasLength(1));
    expect(await queue.readDue('user-2'), isEmpty);
    expect(queue.events.single.id, originalEvent.id);
  });
}
