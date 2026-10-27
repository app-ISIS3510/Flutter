import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late Map<String, dynamic> row;
  late List<http.Request> writes;
  var applied = 0;

  setUp(() async {
    writes = [];
    applied = 0;
    row = {
      'id': 'session-1',
      'user_id': 'user-1',
      'parking_id': 'parking-1',
      'pickup_time': '2026-10-26T22:00:00.000Z',
      'started_at': '2026-10-26T20:00:00.000Z',
      'status': 'active',
    };
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        Object result = [row];
        if (request.method == 'PATCH') {
          writes.add(request);
          final matchesStatus =
              request.url.queryParameters['status'] == 'eq.${row['status']}';
          final expectedTime = request.url.queryParameters['pickup_time'];
          final matchesTime =
              expectedTime == null ||
              expectedTime == 'eq.${row['pickup_time']}';
          if (matchesStatus && matchesTime) {
            row.addAll(jsonDecode(request.body) as Map<String, dynamic>);
            applied++;
          } else {
            result = <Object>[];
          }
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signInAs(client, 'user-1');
  });
  tearDown(() async => client.dispose());

  test('ending twice preserves the first confirmed end time', () async {
    final repository = SessionRepository(client);
    final first = await repository.endSession(sessionId: 'session-1');
    final second = await repository.endSession(sessionId: 'session-1');

    expect(first.endedAt, second.endedAt);
    expect(applied, 1);
    expect(
      writes.every(
        (request) => request.url.queryParameters['status'] == 'eq.active',
      ),
      isTrue,
    );
    expect(
      writes.every(
        (request) => request.url.queryParameters['user_id'] == 'eq.user-1',
      ),
      isTrue,
    );
  });

  test(
    'a delayed pickup change cannot overwrite a more recent server value',
    () async {
      row['pickup_time'] = '2026-10-26T23:00:00.000Z';
      await expectLater(
        SessionRepository(client).updatePickupTime(
          sessionId: 'session-1',
          pickupTime: DateTime.utc(2026, 10, 26, 22, 30),
          previousPickupTime: DateTime.utc(2026, 10, 26, 22),
        ),
        throwsA(isA<ConnectionFailure>()),
      );

      expect(applied, 0);
      expect(row['pickup_time'], '2026-10-26T23:00:00.000Z');
      expect(
        writes.single.url.queryParameters['pickup_time'],
        'eq.2026-10-26T22:00:00.000Z',
      );
    },
  );
}
