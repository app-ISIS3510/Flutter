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
  late List<Map<String, dynamic>> rows;
  Completer<void>? pendingResponse;
  Map<String, String>? selectedParking;
  var online = true;
  var requests = 0;

  setUp(() {
    original = GeolocatorPlatform.instance;
    location = FakeLocationPlatform();
    GeolocatorPlatform.instance = location;
    rows = [parkingData()];
    selectedParking = null;
    pendingResponse = null;
    online = true;
    requests = 0;
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path ==
            '/rest/v1/bq2_top_parking_completed_last_7_days') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        requests++;
        if (!online) throw http.ClientException('No connection');
        await pendingResponse?.future;
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
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
          onSelectParking: (parking) => selectedParking = parking,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> scrollTo(
    WidgetTester tester,
    Finder target,
    double delta,
  ) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('filters and results can be scrolled on a $size phone', (
      tester,
    ) async {
      await openList(tester, size: size);
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('City U Parking'), 200);
      expect(tester.takeException(), isNull);
      expect(find.text('Profile').hitTestable(), findsOneWidget);
      await tester.tap(find.text('City U Parking'));
      expect(selectedParking?['id'], 'parking-1');
      await scrollTo(tester, find.text('Refresh location'), -200);
      await tester.tap(find.text('Refresh location'));
      await tester.pumpAndSettle();
      expect(location.positionCalls, 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('larger text fits the filters and recommendation card', (
    tester,
  ) async {
    await openList(tester, textScale: 1.5);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('City U Parking'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'denied GPS keeps selectable parking lots and recovers after refresh',
    (tester) async {
      location.permission = LocationPermission.denied;
      location.requestedPermission = LocationPermission.denied;
      await openList(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('without distances or a radius filter'),
        findsOneWidget,
      );
      await scrollTo(tester, find.text('City U Parking'), 200);
      final card = tester.widget<ParkingCard>(find.byType(ParkingCard).first);
      expect(card.distance, isNull);
      expect(card.isRecommended, isFalse);
      await tester.tap(find.text('City U Parking'));
      expect(selectedParking?['id'], 'parking-1');
      location.permission = LocationPermission.whileInUse;
      await scrollTo(tester, find.text('Refresh location'), -200);
      await tester.tap(find.text('Refresh location'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('without distances or a radius filter'),
        findsNothing,
      );
      await scrollTo(tester, find.text('City U Parking'), 200);
      final updated = tester.widget<ParkingCard>(
        find.byType(ParkingCard).first,
      );
      expect(updated.distance, isNotNull);
      expect(updated.isRecommended, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('server errors have an accessible retry on a small phone', (
    tester,
  ) async {
    online = false;
    await openList(tester, size: const Size(320, 568));
    await tester.pump(const Duration(seconds: 13));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Try again'), 200);
    expect(find.text('Try again').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('City U Parking'), 200);
    expect(find.text('Unable to load parking lots.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching vehicle type updates capacity and availability', (
    tester,
  ) async {
    await openList(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Motorcycle'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('City U Parking'), 200);
    final card = tester.widget<ParkingCard>(find.byType(ParkingCard).first);
    expect(card.totalSpaces, 10);
    expect(card.availableSpaces, 7);
    expect(card.availabilityPercentage, 70);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty radius can be expanded to find parking', (
    tester,
  ) async {
    rows = [parkingData(latitude: 4.612)];
    await openList(tester);
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.text('No parking lots found within the selected radius.'),
      200,
    );
    await scrollTo(tester, find.text('2 km'), -200);
    await tester.tap(find.text('2 km'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('City U Parking'), 200);
    expect(find.byType(ParkingCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters and refresh wait for the current request', (
    tester,
  ) async {
    pendingResponse = Completer<void>();
    await openList(tester);
    final refresh = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Refresh location'),
    );
    final motorcycle = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Motorcycle'),
    );
    expect(refresh.onPressed, isNull);
    expect(motorcycle.onPressed, isNull);
    expect(requests, 1);
    pendingResponse!.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Refresh location'),
          )
          .onPressed,
      isNotNull,
    );
    expect(location.positionCalls, 1);
  });
}
