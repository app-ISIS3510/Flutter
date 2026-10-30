import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/repositories/analytics_repository.dart';
import 'package:parku/models/parking_summary.dart';
import 'package:parku/repositories/session_history_repository.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/repositories/user_repository.dart';
import 'package:parku/screens/main_navigation.dart';
import 'package:parku/services/pickup_analytics_service.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart';
import 'support/parking_fakes.dart';

class FlowHistory extends SessionHistoryRepository {
  final summaries = <ParkingSummary>[];
  FlowHistory(super.client);

  @override
  Future<void> saveSummary(ParkingSummary summary) async =>
      summaries.add(summary);

  @override
  Future<List<ParkingSummary>> getSavedSessions() async => List.of(summaries);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var online = true;
  var showParking = false;
  Map<String, dynamic>? session;
  final events = <Map<String, dynamic>>[];

  setUp(() async {
    online = true;
    showParking = false;
    session = null;
    events.clear();
    final parking = {
      ...parkingData(),
      'opening_time': '00:00:00',
      'closing_time': '23:59:00',
    };
    final user = {
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'user-1@example.com',
      'created_at': '2026-10-01T00:00:00Z',
      'user_metadata': {'full_name': 'Alex Rivera'},
      'app_metadata': <String, dynamic>{},
    };
    await Supabase.initialize(
      url: 'https://test.invalid',
      publishableKey: 'test-key',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        pkceAsyncStorage: MemoryAuthStorage(),
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        if (!online) throw const SocketException('Offline');
        Object body = [];
        switch (request.url.path) {
          case '/auth/v1/user':
            body = user;
          case '/rest/v1/vehicles':
            body = [
              {
                'id': 'vehicle-1',
                'vehicle_type': 'motorcycle',
                'plate': 'ABC12D',
                'is_selected': true,
              },
            ];
          case '/rest/v1/parking_lots_with_availability':
            if (!showParking) return http.Response('{}', 400);
            body = request.url.queryParameters.containsKey('id')
                ? parking
                : [parking];
          case '/rest/v1/rpc/start_parking_with_vehicle':
            final input = jsonDecode(request.body) as Map<String, dynamic>;
            session = {
              'id': 'session-1',
              'user_id': 'user-1',
              'parking_id': input['p_parking_id'],
              'vehicle_id': input['p_vehicle_id'],
              'vehicle_type': 'motorcycle',
              'vehicle_plate': 'ABC12D',
              'pickup_time': input['p_pickup_time'],
              'started_at': DateTime.now().toUtc().toIso8601String(),
              'status': 'active',
            };
            body = session!;
          case '/rest/v1/parking_sessions':
            if (request.method == 'PATCH') {
              session!.addAll(jsonDecode(request.body) as Map<String, dynamic>);
            }
            body = session == null ? [] : [session];
          case '/rest/v1/analytics_events':
            events.add(jsonDecode(request.body) as Map<String, dynamic>);
          case '/rest/v1/app_admins':
          case '/rest/v1/favorites':
          case '/rest/v1/bq2_top_parking_completed_last_7_days':
            body = [];
          default:
            throw StateError('Unexpected request: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final client = Supabase.instance.client;
    await signInAs(client, 'user-1');
  });
  tearDown(() async => Supabase.instance.dispose());

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets(
      'the visible parking flow records BQ9 and opens an offline summary at ${size.width}',
      (tester) async {
        final client = Supabase.instance.client;
        final store = UserLocalStore.memory(client);
        final history = FlowHistory(client);
        final analytics = PickupAnalyticsService(
          AnalyticsRepository(client),
          store,
        );
        final service = SessionService(
          SessionRepository(client),
          store: store,
          historyRepository: history,
          pickupAnalytics: analytics,
        );
        final originalLocation = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = FakeLocationPlatform();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          GeolocatorPlatform.instance = originalLocation;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
            home: MainNavigationScreen(
              currentTime: () => DateTime(2026, 10, 29, 12),
              profileService: ProfileService(
                SupabaseUserRepository(client),
                store: store,
              ),
              sessionService: service,
              connectionChanges: const Stream<List<ConnectivityResult>>.empty(),
              checkConnection: () async => [ConnectivityResult.none],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Home layout');
        showParking = true;
        await tester.tap(find.text('Parking lots'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Parking list layout');
        await tester.scrollUntilVisible(
          find.text('City U Parking'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('City U Parking'));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Parking details layout',
        );
        await tester.ensureVisible(find.text('Park here'));
        await tester.tap(find.text('Park here'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Pickup time layout');
        expect(find.textContaining('Suggested pickup time:'), findsOneWidget);
        await tester.ensureVisible(find.text('Start parking'));
        await tester.tap(find.text('Start parking'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Active parking layout');
        await analytics.flush();
        expect(session?['status'], 'active');
        final choice = events.singleWhere(
          (event) => event['event_type'] == 'parking_pickup_choice',
        );
        expect(choice['metadata']['pickup_selection'], 'suggested');
        expect(choice['metadata']['session_id'], 'session-1');
        await tester.ensureVisible(find.text('I picked up my vehicle'));
        await tester.tap(find.text('I picked up my vehicle'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'End parking layout');
        await tester.ensureVisible(find.text("Yes, I've picked it up"));
        await tester.tap(find.text("Yes, I've picked it up"));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'No active parking layout',
        );
        expect(session?['status'], 'completed');

        online = false;
        final saved = await history.getSavedSessions();
        expect(saved.single.parkingName, 'City U Parking');
        expect(saved.single.vehiclePlate, 'ABC12D');
        expect(await store.read('session_request'), isNull);
        await tester.tap(find.text('Profile').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Saved parking'));
        await tester.tap(find.text('Saved parking'));
        await tester.pumpAndSettle();
        expect(find.text('City U Parking'), findsOneWidget);
        expect(find.text('Motorcycle · ABC12D'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
