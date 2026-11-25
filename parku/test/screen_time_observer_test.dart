import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/repositories/analytics_repository.dart';
import 'package:parku/services/analytics_service.dart';
import 'package:parku/services/connectivity_service.dart';
import 'package:parku/utils/screen_time_observer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/analytics_queue.dart';
import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart' show signInAs;

class _Connection extends ConnectivityService {
  bool online = false;

  @override
  Future<bool> hasNetworkConnection() async => online;
}

void main() {
  late SupabaseClient client;
  final payloads = <Map<String, dynamic>>[];

  setUp(() async {
    payloads.clear();
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        payloads.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', 201, request: request);
      }),
    );
    await signInAs(client, 'user-1');
  });
  tearDown(() async => client.dispose());

  testWidgets('queues time only for the active page and sends it when online', (
    tester,
  ) async {
    final queue = TestAnalyticsQueue();
    final connection = _Connection();
    final analytics = AnalyticsService(
      AnalyticsRepository(client, localDataSource: queue),
      connectivityService: connection,
    );
    addTearDown(analytics.dispose);

    final started = DateTime.utc(2026, 11, 24);
    var elapsed = Duration.zero;
    final observer = ScreenTimeObserver(
      elapsed: () => elapsed,
      now: () => started.add(elapsed),
    );
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        home: const Scaffold(),
      ),
    );
    observer.start(analytics);
    observer.setLifecycleState(AppLifecycleState.resumed);

    elapsed += const Duration(seconds: 2);
    observer.setHomeScreen('parking_list');
    elapsed += const Duration(seconds: 3);
    navigator.currentState!.push<void>(
      ScreenTimeRoute(
        screen: 'parking_detail',
        builder: (_) => const Scaffold(),
      ),
    );
    await tester.pumpAndSettle();

    elapsed += const Duration(seconds: 4);
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(title: Text('Confirm')),
    );
    await tester.pumpAndSettle();
    elapsed += const Duration(seconds: 20);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    elapsed += const Duration(seconds: 5);
    observer.setLifecycleState(AppLifecycleState.inactive);
    observer.setLifecycleState(AppLifecycleState.paused);
    elapsed += const Duration(minutes: 10);
    await tester.pump(const Duration(minutes: 10));
    observer.setLifecycleState(AppLifecycleState.resumed);
    elapsed += const Duration(minutes: 1);
    await tester.pump(const Duration(minutes: 1));
    elapsed += const Duration(seconds: 1);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(payloads, isEmpty);
    final events = await queue.readDue('user-1');
    expect(
      events.map((event) => (event.screen, event.metadata['duration_ms'])),
      [
        ('map', 2000),
        ('parking_list', 3000),
        ('parking_detail', 4000),
        ('parking_detail', 5000),
        ('parking_detail', 60000),
        ('parking_detail', 1000),
      ],
    );
    expect(events.first.createdAt, started.add(const Duration(seconds: 2)));
    expect(events.first.metadata, {'duration_ms': 2000, 'platform': 'flutter'});

    await signInAs(client, 'user-2');
    elapsed += const Duration(seconds: 3);
    observer.stop(analytics);
    expect(await queue.readDue('user-2'), isEmpty);

    await signInAs(client, 'user-1');
    connection.online = true;
    await tester.runAsync(analytics.flushPending);
    expect(
      payloads.map((payload) => payload['id']),
      events.map((event) => event.id),
    );
    expect(
      payloads.every((event) => event['event_type'] == 'screen_time_spent'),
      isTrue,
    );
    expect(await queue.readDue('user-1'), isEmpty);
  });
}
