import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/session_controller.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/models/parking_summary.dart';
import 'package:parku/repositories/session_history_repository.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:parku/services/session_service.dart';
import 'package:parku/state/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';

Map<String, dynamic> completedSession({
  String id = 'session-1',
  String userId = 'user-1',
  String endedAt = '2026-10-26T17:00:00Z',
}) {
  return {
    'id': id,
    'user_id': userId,
    'parking_id': 'parking-1',
    'pickup_time': '2026-10-26T17:30:00Z',
    'started_at': '2026-10-26T16:00:00Z',
    'ended_at': endedAt,
    'status': 'completed',
    'vehicle_type': 'car',
    'vehicle_plate': 'ABC123',
  };
}

ParkingSummary summary({String id = 'session-1', String userId = 'user-1'}) {
  return ParkingSummary.fromSession(
    ParkingSession.fromMap(completedSession(id: id, userId: userId)),
    parkingName: 'City U Parking',
  );
}

Future<void> signIn(SupabaseClient client, String userId) async {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': userId,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      )
      .replaceAll('=', '');
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '$userId@example.com',
        'created_at': '2026-10-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SupabaseClient client;
  late SessionHistoryRepository history;
  var serverAvailable = true;
  var networkCalls = 0;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('parku-history-test-');
    serverAvailable = true;
    networkCalls = 0;
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        networkCalls++;
        if (request.url.path == '/auth/v1/logout') {
          return http.Response('{}', 200);
        }
        if (!serverAvailable) throw const SocketException('Offline');
        if (request.url.path != '/rest/v1/parking_sessions' ||
            request.method != 'PATCH') {
          throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode([completedSession()]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signIn(client, 'user-1');
    history = SessionHistoryRepository(
      client,
      getDirectory: () async => directory,
    );
  });

  tearDown(() async {
    await client.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'saved summaries survive reopening the repository without internet',
    () async {
      await history.saveSummary(summary());
      serverAvailable = false;
      final reopened = SessionHistoryRepository(
        client,
        getDirectory: () async => directory,
      );

      final saved = await reopened.getSavedSessions();

      expect(saved.single.parkingName, 'City U Parking');
      expect(saved.single.vehiclePlate, 'ABC123');
      expect(saved.single.endedAt, DateTime.utc(2026, 10, 26, 17));
      expect(networkCalls, 0);
    },
  );

  test(
    'each account reads only its own files, including after signing out',
    () async {
      await history.saveSummary(summary());
      await client.auth.signOut(scope: SignOutScope.local);
      await expectLater(
        history.getSavedSessions(),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        history.saveSummary(summary()),
        throwsA(isA<AuthException>()),
      );

      await signIn(client, 'user-2');
      expect(await history.getSavedSessions(), isEmpty);
      await history.saveSummary(summary(id: 'session-2', userId: 'user-2'));
      expect((await history.getSavedSessions()).single.sessionId, 'session-2');
      await expectLater(
        history.saveSummary(summary()),
        throwsA(isA<AuthException>()),
      );

      await signIn(client, 'user-1');
      expect((await history.getSavedSessions()).single.sessionId, 'session-1');
    },
  );

  test(
    'changing accounts while reading does not return the previous history',
    () async {
      await history.saveSummary(summary());
      final pendingDirectory = Completer<Directory>();
      final delayed = SessionHistoryRepository(
        client,
        getDirectory: () => pendingDirectory.future,
      );
      final reading = delayed.getSavedSessions();

      await signIn(client, 'user-2');
      pendingDirectory.complete(directory);

      expect(await reading, isEmpty);
    },
  );

  test(
    'changing accounts before a write completes does not save the summary',
    () async {
      final pendingDirectory = Completer<Directory>();
      final delayed = SessionHistoryRepository(
        client,
        getDirectory: () => pendingDirectory.future,
      );
      final writing = delayed.saveSummary(summary());
      final rejected = expectLater(writing, throwsA(isA<AuthException>()));

      await signIn(client, 'user-2');
      pendingDirectory.complete(directory);
      await rejected;

      await signIn(client, 'user-1');
      expect(await history.getSavedSessions(), isEmpty);
    },
  );

  test(
    'saving a session again replaces its file and keeps newest sessions first',
    () async {
      await history.saveSummary(summary());
      final latest = ParkingSummary.fromSession(
        ParkingSession.fromMap(
          completedSession(id: 'session-2', endedAt: '2026-10-26T18:00:00Z'),
        ),
        parkingName: 'MetroPark Center',
      );
      await history.saveSummary(latest);
      await history.saveSummary(summary());

      expect((await history.getSavedSessions()).map((item) => item.sessionId), [
        'session-2',
        'session-1',
      ]);
      final files = await directory
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(files.length, 2);
      expect(files.every((file) => file.path.endsWith('.json')), isTrue);
    },
  );

  test(
    'different sessions can be saved together without losing a file',
    () async {
      await Future.wait([
        history.saveSummary(summary(id: 'session-1')),
        history.saveSummary(summary(id: 'session-2')),
        history.saveSummary(summary(id: 'session-3')),
      ]);

      expect((await history.getSavedSessions()).length, 3);
    },
  );

  test(
    'a summary with another owner is never returned even from the same folder',
    () async {
      await history.saveSummary(summary());
      final file =
          (await directory
                      .list(recursive: true)
                      .where((e) => e is File)
                      .toList())
                  .single
              as File;
      await file.writeAsString(jsonEncode(summary(userId: 'user-2').toMap()));

      expect(await history.getSavedSessions(), isEmpty);
    },
  );

  test(
    'invalid files report an error without replacing the saved contents',
    () async {
      await history.saveSummary(summary());
      final file =
          (await directory
                      .list(recursive: true)
                      .where((e) => e is File)
                      .toList())
                  .single
              as File;
      await file.writeAsString('invalid json');

      await expectLater(
        history.getSavedSessions(),
        throwsA(isA<FormatException>()),
      );
      expect(await file.readAsString(), 'invalid json');
    },
  );

  test('active sessions cannot be converted into saved completed stays', () {
    final active = completedSession()
      ..['status'] = 'active'
      ..['ended_at'] = null;

    expect(
      () => ParkingSummary.fromSession(
        ParkingSession.fromMap(active),
        parkingName: 'City U Parking',
      ),
      throwsArgumentError,
    );
  });

  test('ending a confirmed parking session saves its summary', () async {
    final service = SessionService(
      SessionRepository(client),
      historyRepository: history,
    );
    final state = SessionState();
    addTearDown(state.dispose);
    final controller = SessionController(service, state);

    final ended = await controller.endParking(
      sessionId: 'session-1',
      parkingName: 'City U Parking',
    );

    expect(ended.status, 'completed');
    expect((await history.getSavedSessions()).single.sessionId, ended.id);
    expect(service.historySaveFailed, isFalse);
    expect(state.activeSession, isNull);
  });

  test('a failed server operation does not create a saved summary', () async {
    serverAvailable = false;
    final service = SessionService(
      SessionRepository(client),
      historyRepository: history,
    );

    await expectLater(
      service.endParking(sessionId: 'session-1'),
      throwsA(isA<SocketException>()),
    );

    expect(await history.getSavedSessions(), isEmpty);
  });

  test('a local write failure does not undo a confirmed parking end', () async {
    final unavailableHistory = SessionHistoryRepository(
      client,
      getDirectory: () async =>
          throw const FileSystemException('Storage unavailable'),
    );
    final service = SessionService(
      SessionRepository(client),
      historyRepository: unavailableHistory,
    );
    final state = SessionState();
    addTearDown(state.dispose);
    final controller = SessionController(service, state);

    final ended = await controller.endParking(sessionId: 'session-1');

    expect(ended.status, 'completed');
    expect(service.historySaveFailed, isTrue);
    expect(state.activeSession, isNull);
  });
}
