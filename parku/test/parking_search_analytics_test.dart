import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/analytics_controller.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/models/analytics_measurements.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/parking_search_result.dart';
import 'package:parku/screens/search_results.dart';

import 'support/parking_fakes.dart';

class _SearchController extends Fake implements ParkingController {
  final Future<ParkingSearchResult> Function(String) search;

  _SearchController(this.search);

  @override
  Future<ParkingSearchResult> searchParkingLotsWithSource(String query) =>
      search(query);
}

class _AnalyticsController extends Fake implements AnalyticsController {
  final searchEvents = <Map<String, dynamic>>[];

  @override
  String get currentUserId => 'user-1';

  @override
  Future<void> track({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) async {
    if (eventType == 'screen_load_completed' && screen == 'search_results') {
      searchEvents.add(metadata!);
    }
  }
}

void main() {
  final parking = Parking.fromMap(parkingData());

  for (final isFromCache in [false, true]) {
    final source = isFromCache ? 'cache' : 'network';
    testWidgets('attributes a detail visit to presented $source results', (
      tester,
    ) async {
      final analytics = _AnalyticsController();
      final measurement = ScreenLoadMeasurement();
      ParkingDetailVisit? visit;

      await tester.pumpWidget(
        MaterialApp(
          home: SearchResultsScreen(
            initialQuery: 'city',
            initialMeasurement: measurement,
            currentIndex: 1,
            onNavTap: (_) {},
            onSelectParking: (data, {searchId}) {
              visit = ParkingDetailVisit(data['id']!, searchId: searchId);
            },
            parkingController: _SearchController(
              (_) async => ParkingSearchResult(
                parkingLots: [parking],
                isFromCache: isFromCache,
              ),
            ),
            analytics: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final metadata = analytics.searchEvents.single;
      expect(metadata['search_id'], measurement.id);
      expect(metadata['search_method'], 'text');
      expect(metadata['cache_source'], source);
      expect(metadata['is_from_cache'], isFromCache);
      expect(metadata['result_count'], 1);
      expect(metadata['duration_ms'], greaterThanOrEqualTo(0));
      expect(metadata.containsKey('query'), isFalse);

      final card = find.text(parking.name);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(visit?.parkingId, parking.id);
      expect(visit?.markViewed()?['search_id'], metadata['search_id']);
      expect(visit?.markViewed(), isNull);
      expect(analytics.searchEvents, hasLength(1));
    });
  }

  testWidgets('excludes superseded and empty searches from BQ13', (
    tester,
  ) async {
    final analytics = _AnalyticsController();
    final superseded = Completer<ParkingSearchResult>();
    await tester.pumpWidget(
      MaterialApp(
        home: SearchResultsScreen(
          initialQuery: 'city',
          currentIndex: 1,
          onNavTap: (_) {},
          parkingController: _SearchController(
            (query) => query == 'city'
                ? superseded.future
                : Future.value(const ParkingSearchResult(parkingLots: [])),
          ),
          analytics: analytics,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'no matches');
    superseded.complete(ParkingSearchResult(parkingLots: [parking]));
    await tester.pump();
    expect(analytics.searchEvents, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No search results'), findsOneWidget);
    expect(analytics.searchEvents.single.containsKey('search_id'), isFalse);
    expect(ParkingDetailVisit(parking.id).markViewed()!['search_id'], isNull);
  });
}
