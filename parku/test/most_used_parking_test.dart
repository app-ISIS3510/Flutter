import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/screens/parking_list.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:parku/widgets/parking_card.dart';
import 'package:parku/widgets/most_used_parking_section.dart';
import 'package:parku/widgets/offline_data_status_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/data/local/parking_local_data_source.dart';
import 'package:parku/services/connectivity_service.dart';

import 'support/parking_fakes.dart';
import 'support/memory_auth_storage.dart';
import 'support/offline_fakes.dart' show signInAs;

class TestConnectivityService extends ConnectivityService {
  bool online = true;

  @override
  Future<bool> hasNetworkConnection() async => online;

  @override
  Future<bool?> connectionStatus() async => online;

  @override
  Stream<bool> get onNetworkChanged => const Stream<bool>.empty();
}

class TestParkingLocalDataSource extends ParkingLocalDataSource {
  CachedParking? parking;

  @override
  Future<CachedParkingList?> readParkingLots() async => null;

  @override
  Future<CachedParkingList?> readParkingForNearby() async => null;

  @override
  Future<void> saveParkingLots(List<Parking> parkingLots) async {}

  @override
  Future<void> saveParking(Parking parking) async {}

  @override
  Future<CachedParking?> readParkingById(String id) async =>
      parking?.parking.id == id ? parking : null;
}

void main() {
  late GeolocatorPlatform original;
  late FakeLocationPlatform location;
  late SupabaseClient client;
  late ParkingController controller;
  late UserLocalStore store;
  late TestConnectivityService connectivity;
  late TestParkingLocalDataSource localData;
  late List<Map<String, dynamic>> ranking;
  late List<Map<String, dynamic>> lots;
  var rankingCalls = 0;
  var detailCalls = 0;
  var rankingFails = false;
  var detailFails = false;
  var detailMissing = false;
  http.Request? rankingRequest;
  Completer<void>? rankingGate;
  Completer<void>? detailGate;
  Map<String, String>? selected;

  setUp(() async {
    original = GeolocatorPlatform.instance;
    location = FakeLocationPlatform();
    GeolocatorPlatform.instance = location;
    ranking = [
      {
        'parking_id': 'popular',
        'parking_name': 'Popular lot',
        'completed_sessions': 8,
      },
    ];
    lots = [
      parkingData(id: 'popular', name: 'Popular lot', latitude: 4.65),
      parkingData(id: 'nearby', name: 'Nearby lot'),
    ];
    rankingCalls = 0;
    detailCalls = 0;
    rankingFails = false;
    detailFails = false;
    detailMissing = false;
    rankingRequest = null;
    rankingGate = null;
    detailGate = null;
    selected = null;
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        Object? body;
        if (request.url.path ==
            '/rest/v1/bq2_top_parking_completed_last_7_days') {
          rankingCalls++;
          rankingRequest = request;
          await rankingGate?.future;
          if (rankingFails) throw http.ClientException('Offline');
          body = ranking;
        } else if (request.url.path ==
            '/rest/v1/parking_lots_with_availability') {
          final id = request.url.queryParameters['id'];
          if (id != null) {
            detailCalls++;
            await detailGate?.future;
            if (detailFails) throw http.ClientException('Offline');
            body = detailMissing
                ? null
                : lots.firstWhere((lot) => id == 'eq.${lot['id']}');
          } else {
            body = lots;
          }
        } else {
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
    await signInAs(client, 'ranking-user');
    store = UserLocalStore.memory(client);
    connectivity = TestConnectivityService();
    localData = TestParkingLocalDataSource();
    controller = ParkingController(
      ParkingService(
        ParkingRepository(
          client,
          localDataSource: localData,
          connectivityService: connectivity,
        ),
        DistanceManager(),
        connectivityService: connectivity,
        store: store,
      ),
    );
  });

  tearDown(() async {
    GeolocatorPlatform.instance = original;
    await client.dispose();
  });

  test(
    'reads the existing BQ2 aggregate without querying user data or GPS',
    () async {
      ranking.add({
        'parking_id': 'nearby',
        'parking_name': 'Nearby lot',
        'completed_sessions': 3,
      });
      final results = await controller.loadMostUsedParkingLots();
      expect(results.map((lot) => lot.completedSessions), [8, 3]);
      expect(results.first.parkingId, 'popular');
      expect(
        rankingRequest!.url.queryParameters['select'],
        'parking_id,parking_name,completed_sessions',
      );
      expect(
        rankingRequest!.url.queryParameters['order'],
        'completed_sessions.desc.nullslast,parking_id.asc.nullslast',
      );
      expect(rankingRequest!.url.queryParameters['limit'], '3');
      expect(location.positionCalls, 0);
      expect(rankingCalls, 1);
    },
  );

  test(
    'keeps an empty week empty instead of creating example results',
    () async {
      ranking = [];
      expect(await controller.loadMostUsedParkingLots(), isEmpty);
    },
  );

  Future<void> openList(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ParkingListScreen(
          currentIndex: 1,
          onNavTap: (_) {},
          controller: controller,
          onSelectParking: (parking) => selected = parking,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    Finder finder,
    double delta,
  ) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
  }

  testWidgets('an empty week explains the missing history', (tester) async {
    ranking = [];
    await openList(tester);
    await tester.pumpAndSettle();
    expect(find.text('Most used parking lots this week'), findsOneWidget);
    expect(
      find.text(
        'No completed parking sessions were recorded in the last 7 days.',
      ),
      findsOneWidget,
    );
    expect(find.text('8 completed sessions'), findsNothing);
  });

  testWidgets(
    'the ranking works without GPS and opens a lot outside the selected radius',
    (tester) async {
      location.permission = LocationPermission.deniedForever;
      await openList(tester);
      await tester.pumpAndSettle();
      expect(find.text('8 completed sessions'), findsOneWidget);
      await scrollTo(tester, find.text('8 completed sessions'), 200);
      await tester.tap(find.text('8 completed sessions'));
      await tester.pumpAndSettle();
      expect(detailCalls, 1);
      expect(selected?['id'], 'popular');
      expect(selected?['latitude'], '4.65');
      expect(selected?['name'], 'Popular lot');
      expect(location.positionCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a ranking failure does not block nearby parking and can be retried',
    (tester) async {
      rankingFails = true;
      await openList(tester);
      await tester.pumpAndSettle();
      expect(find.text('Retry ranking'), findsOneWidget);
      await scrollTo(tester, find.text('Nearby lot'), 200);
      expect(find.byType(ParkingCard), findsOneWidget);
      await scrollTo(tester, find.text('Retry ranking'), -200);
      final failedAttempts = rankingCalls;
      rankingFails = false;
      await tester.tap(find.text('Retry ranking'));
      await tester.pumpAndSettle();
      expect(find.text('8 completed sessions'), findsOneWidget);
      expect(rankingCalls, failedAttempts + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing vehicle filters does not reload BQ2 and ranking refresh updates counts',
    (tester) async {
      await openList(tester);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Motorcycle'), 200);
      await tester.tap(find.text('Motorcycle'));
      await tester.pumpAndSettle();
      expect(rankingCalls, 1);
      final fixes = location.positionCalls;
      ranking[0] = {
        'parking_id': 'popular',
        'parking_name': 'Popular lot',
        'completed_sessions': 12,
      };
      await scrollTo(tester, find.text('Refresh ranking'), -200);
      await tester.tap(find.text('Refresh ranking'));
      await tester.pumpAndSettle();
      expect(find.text('12 completed sessions'), findsOneWidget);
      expect(rankingCalls, 2);
      expect(location.positionCalls, fixes);
    },
  );

  testWidgets(
    'failed or missing parking details give feedback without navigating',
    (tester) async {
      await openList(tester);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('8 completed sessions'), 200);
      detailFails = true;
      await tester.tap(find.text('8 completed sessions'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(
        find.text('Could not open this parking lot. Please try again later.'),
        findsOneWidget,
      );
      detailFails = false;
      detailMissing = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8 completed sessions'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(
        find.text(
          'This parking lot is no longer available. Refresh the ranking.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opening a parking lot twice shares the pending action', (
    tester,
  ) async {
    detailGate = Completer<void>();
    await openList(tester);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('8 completed sessions'), 200);
    await tester.tap(find.text('8 completed sessions'));
    await tester.pump();
    await tester.tap(find.text('8 completed sessions'));
    await tester.pump();
    expect(detailCalls, 1);
    detailGate!.complete();
    await tester.pumpAndSettle();
    expect(selected?['id'], 'popular');
  });

  testWidgets('a stalled ranking stops loading and offers a retry', (
    tester,
  ) async {
    rankingGate = Completer<void>();
    await openList(tester);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Retry ranking'), findsOneWidget);
    rankingGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Retry ranking'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved ranking shows its date and opens cached parking details', (
    tester,
  ) async {
    final live = await controller.loadMostUsedParkingRanking();
    connectivity.online = false;
    localData.parking = CachedParking(
      parking: Parking.fromMap(lots.first),
      cachedAt: live.updatedAt,
    );
    await openList(tester);
    await tester.pumpAndSettle();
    expect(find.text('Most used parking lots (saved)'), findsOneWidget);
    expect(find.text('Saved ranking'), findsOneWidget);
    expect(
      find.text('Top 3 in the 7 days before the last update.'),
      findsOneWidget,
    );
    final status = tester.widget<OfflineDataStatusIndicator>(
      find.descendant(
        of: find.byType(MostUsedParkingSection),
        matching: find.byType(OfflineDataStatusIndicator),
      ),
    );
    expect(status.updatedAt, live.updatedAt);
    expect(rankingCalls, 1);
    await scrollTo(tester, find.text('8 completed sessions'), 200);
    await tester.tap(find.text('8 completed sessions'));
    await tester.pumpAndSettle();
    expect(selected?['id'], 'popular');
    expect(detailCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'offline refresh keeps the saved result and reconnect replaces it',
    (tester) async {
      final live = await controller.loadMostUsedParkingRanking();
      connectivity.online = false;
      await openList(tester);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Refresh ranking'), 200);
      await tester.tap(find.text('Refresh ranking'));
      await tester.pumpAndSettle();
      expect(find.text('8 completed sessions'), findsOneWidget);
      expect(find.text('Saved ranking'), findsOneWidget);
      expect(rankingCalls, 1);
      expect(
        (await store.read('most_used_parking_ranking'))!['updated_at'],
        live.updatedAt.toIso8601String(),
      );
      connectivity.online = true;
      ranking[0]['completed_sessions'] = 12;
      await tester.tap(find.text('Refresh ranking'));
      await tester.pumpAndSettle();
      expect(find.text('12 completed sessions'), findsOneWidget);
      expect(find.text('Saved ranking'), findsNothing);
      expect(find.text('Most used parking lots this week'), findsOneWidget);
      expect(rankingCalls, 2);
    },
  );

  testWidgets('a cached empty week refers to the saved period', (tester) async {
    ranking = [];
    await controller.loadMostUsedParkingRanking();
    connectivity.online = false;
    await openList(tester);
    await tester.pumpAndSettle();
    expect(find.text('Saved ranking'), findsOneWidget);
    expect(
      find.text(
        'No completed parking sessions were recorded in the saved period.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No completed parking sessions were recorded in the last 7 days.',
      ),
      findsNothing,
    );
  });

  testWidgets('a stalled parking detail request can still open saved details', (
    tester,
  ) async {
    localData.parking = CachedParking(
      parking: Parking.fromMap(lots.first),
      cachedAt: DateTime.now().toUtc(),
    );
    detailGate = Completer<void>();
    await openList(tester);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('8 completed sessions'), 200);
    await tester.tap(find.text('8 completed sessions'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(selected?['id'], 'popular');
    expect(detailCalls, 1);
    detailGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved ranking with no saved details offers clear feedback', (
    tester,
  ) async {
    await controller.loadMostUsedParkingRanking();
    connectivity.online = false;
    await openList(tester);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('8 completed sessions'), 200);
    await tester.tap(find.text('8 completed sessions'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(
      find.text('Could not open this parking lot. Please try again later.'),
      findsOneWidget,
    );
    expect(detailCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a timed-out refresh uses cache and ignores its late response', (
    tester,
  ) async {
    final live = await controller.loadMostUsedParkingRanking();
    rankingGate = Completer<void>();
    ranking[0]['completed_sessions'] = 20;
    await openList(tester);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('Saved ranking'), findsOneWidget);
    expect(find.text('8 completed sessions'), findsOneWidget);
    rankingGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('20 completed sessions'), findsNothing);
    final saved = (await store.read('most_used_parking_ranking'))!;
    expect(saved['updated_at'], live.updatedAt.toIso8601String());
    expect((saved['parking_lots'] as List).single['completed_sessions'], 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an offline first visit can recover using the ranking retry', (
    tester,
  ) async {
    connectivity.online = false;
    await openList(tester);
    await tester.pumpAndSettle();
    expect(find.text('Retry ranking'), findsOneWidget);
    expect(find.text('Saved ranking'), findsNothing);
    connectivity.online = true;
    await scrollTo(tester, find.text('Retry ranking'), 200);
    await tester.tap(find.text('Retry ranking'));
    await tester.pumpAndSettle();
    expect(find.text('8 completed sessions'), findsOneWidget);
    expect(find.text('Retry ranking'), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('the saved ranking notice fits on a $size phone', (
      tester,
    ) async {
      await controller.loadMostUsedParkingRanking();
      connectivity.online = false;
      await openList(tester, size: size, textScale: 1.5);
      await tester.pumpAndSettle();
      expect(find.text('Saved ranking'), findsOneWidget);
      await scrollTo(tester, find.text('Refresh ranking'), 200);
      expect(find.text('Refresh ranking').hitTestable(), findsOneWidget);
      expect(find.text('Profile').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('three ranked lots fit and scroll on a $size phone', (
      tester,
    ) async {
      ranking = [
        for (var i = 0; i < 3; i++)
          {
            'parking_id': 'popular-$i',
            'parking_name': 'A long parking lot name number $i',
            'completed_sessions': 3 - i,
          },
      ];
      await openList(tester, size: size, textScale: 1.3);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('1 completed session'), 200);
      await scrollTo(tester, find.text('Nearby lot'), 200);
      expect(tester.takeException(), isNull);
      expect(find.text('Profile').hitTestable(), findsOneWidget);
    });
  }
}
