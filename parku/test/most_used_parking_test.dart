import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/screens/parking_list.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:parku/widgets/parking_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/parking_fakes.dart';

void main() {
  late GeolocatorPlatform original;
  late FakeLocationPlatform location;
  late SupabaseClient client;
  late ParkingController controller;
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

  setUp(() {
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
      authOptions: const AuthClientOptions(autoRefreshToken: false),
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
    controller = ParkingController(
      ParkingService(ParkingRepository(client), DistanceManager()),
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
        find.text(
          'Could not open this parking lot. Check your connection and try again.',
        ),
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

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
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
