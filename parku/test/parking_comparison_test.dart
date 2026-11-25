import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/connection_controller.dart';
import 'package:parku/controllers/parking_comparison_controller.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/data/local/parking_comparison_store.dart';
import 'package:parku/data/memory/lfu_cache.dart';
import 'package:parku/models/compared_parking.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/parking_search_result.dart';
import 'package:parku/screens/parking_comparison.dart';
import 'package:parku/screens/search_results.dart';

import 'support/parking_fakes.dart';

class _SearchController extends Fake implements ParkingController {
  final List<Parking> lots;

  _SearchController(this.lots);

  @override
  Future<ParkingSearchResult> searchParkingLotsWithSource(String query) async =>
      ParkingSearchResult(parkingLots: lots);
}

class _ComparisonConnection extends ConnectionController {
  _ComparisonConnection()
    : super(
        onReconnect: () async {},
        changes: const Stream.empty(),
        checkConnection: () async => [],
      );

  void setOnline(bool online) {
    hasNetwork = online;
    notifyListeners();
  }
}

class _MemoryStore implements ParkingComparisonStore {
  final _saved = <String, List<ComparedParking>>{};

  @override
  Future<List<ComparedParking>> read(String owner) async => _saved[owner] ?? [];

  @override
  Future<void> write(String owner, List<ComparedParking> selection) async {
    _saved[owner] = List.of(selection);
  }
}

void main() {
  final lots = [
    for (final name in ['Alpha', 'Bravo', 'Charlie', 'Delta'])
      Parking.fromMap({
        ...parkingData(id: name, name: name),
        'opening_time': '07:00:00',
        'closing_time': '22:00:00',
      }),
  ];

  test('limits selection to three parking lots and preserves their order', () {
    final controller = ParkingComparisonController();
    addTearDown(controller.dispose);
    for (final parking in lots) {
      controller.toggle(parking);
    }
    expect(controller.selection.map((item) => item.parking), lots.take(3));

    controller.toggle(lots.first);
    controller.toggle(lots.last);
    expect(controller.selection.map((item) => item.parking), lots.skip(1));
  });

  test(
    'restores the last ordered selection separately for each account',
    () async {
      final store = _MemoryStore();
      final controller = ParkingComparisonController(store: store);
      addTearDown(controller.dispose);
      await controller.setAccount('camila');
      controller.toggle(lots[1]);
      controller.toggle(lots[0]);
      controller.toggle(lots[2]);
      controller.remove(lots[2].id);

      await controller.setAccount('other');
      expect(controller.selection, isEmpty);
      controller.toggle(lots[3]);
      await controller.setAccount(null);

      final restored = ParkingComparisonController(store: store);
      addTearDown(restored.dispose);
      await restored.setAccount('camila');
      expect(restored.selection.map((item) => item.parking.id), [
        'Bravo',
        'Alpha',
      ]);
      await restored.setAccount('other');
      expect(restored.selection.map((item) => item.parking.id), ['Delta']);
    },
  );

  test(
    'two workers update independently and retain data on a failed read',
    () async {
      final controller = ParkingComparisonController();
      addTearDown(controller.dispose);
      for (final parking in lots.take(3)) {
        controller.toggle(parking);
      }
      final requests = <String, Completer<Parking?>>{};
      final refresh = controller.refresh(
        loadParking: (id) => (requests[id] = Completer<Parking?>()).future,
        shouldContinue: () => true,
      );
      expect(requests.keys, ['Alpha', 'Bravo']);
      requests['Alpha']!.completeError(StateError('No connection'));
      await pumpEventQueue();
      expect(requests.keys, ['Alpha', 'Bravo', 'Charlie']);
      expect(controller.selection.first.isFromCache, isTrue);
      expect(controller.selection.first.parking, lots.first);

      requests['Bravo']!.complete(
        Parking.fromMap(parkingData(id: 'Bravo', name: 'New Bravo')),
      );
      requests['Charlie']!.complete(null);
      expect(await refresh, isFalse);
      expect(controller.selection[1].parking.name, 'New Bravo');
      expect(controller.selection[2].isUnavailable, isTrue);
    },
  );

  test(
    'reuses fresh details, expires them at 60 seconds and supports refresh',
    () async {
      var now = DateTime.utc(2026, 11, 24);
      final controller = ParkingComparisonController(now: () => now);
      addTearDown(controller.dispose);
      controller.toggle(lots.first);
      var requests = 0;
      Future<bool> refresh({bool force = false}) => controller.refresh(
        loadParking: (_) async {
          requests++;
          return lots.first;
        },
        shouldContinue: () => true,
        force: force,
      );

      await refresh();
      now = now.add(const Duration(seconds: 59));
      await refresh();
      expect(requests, 1);
      now = now.add(const Duration(seconds: 1));
      await refresh();
      expect(requests, 2);
      await refresh(force: true);
      expect(requests, 3);
    },
  );

  test(
    'LFU evicts a less-used entry even when it was accessed more recently',
    () {
      final cache = LfuCache<String, int>(2);
      cache.put('Alpha', 1);
      cache.get('Alpha');
      cache.get('Alpha');
      cache.put('Bravo', 2);
      cache.get('Bravo');
      cache.put('Charlie', 3);

      expect(cache.get('Alpha'), 1);
      expect(cache.get('Bravo'), isNull);
      expect(cache.get('Charlie'), 3);
    },
  );

  testWidgets('selects from search, compares and removes on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ParkingComparisonController();
    addTearDown(controller.dispose);
    final connection = _ComparisonConnection()..setOnline(true);
    addTearDown(connection.dispose);
    String? opened;
    var searchDetailTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => SearchResultsScreen(
            initialQuery: 'parking',
            currentIndex: 1,
            onNavTap: (_) {},
            parkingController: _SearchController(lots),
            onSelectParking: (_, {searchId}) => searchDetailTaps++,
            comparison: controller,
            onCompare: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ParkingComparisonScreen(
                  controller: controller,
                  connection: connection,
                  loadParking: (id) async =>
                      lots.firstWhere((lot) => lot.id == id),
                  onOpenDetails: (parking) => opened = parking.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> addParking(String name) async {
      final action = find.byTooltip('Add $name to comparison');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    await addParking('Alpha');
    final compare = find.widgetWithText(FilledButton, 'Compare');
    expect(tester.widget<FilledButton>(compare).onPressed, isNull);
    await addParking('Bravo');
    await addParking('Charlie');
    expect(searchDetailTaps, 0);
    await tester.tap(compare);
    await tester.pumpAndSettle();

    expect(find.text('Compare Parking Lots'), findsOneWidget);
    expect(find.text('COP 100'), findsNWidgets(3));
    expect(find.text('07:00–22:00'), findsNWidgets(3));
    expect(find.text('8 of 20 (est.)'), findsNWidgets(3));

    await tester.drag(find.text('Bravo'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final details = find.byTooltip('Open details for Charlie');
    await tester.tap(details.hitTestable());
    expect(opened, 'Charlie');

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    final remove = find.byTooltip('Remove Charlie from comparison');
    await tester.tap(remove.hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Charlie'), findsNothing);
    expect(find.text('2 of 3 selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps selections editable offline and updates on reconnect', (
    tester,
  ) async {
    final connection = _ComparisonConnection()..setOnline(false);
    final savedAt = DateTime.utc(2026, 11, 24, 13);
    final latest = savedAt.add(const Duration(minutes: 10));
    final controller = ParkingComparisonController(now: () => latest);
    addTearDown(connection.dispose);
    addTearDown(controller.dispose);
    for (final parking in lots.take(3)) {
      controller.toggle(parking, updatedAt: savedAt, isFromCache: true);
    }
    final requests = <Completer<Parking?>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ParkingComparisonScreen(
          controller: controller,
          connection: connection,
          loadParking: (_) {
            final request = Completer<Parking?>();
            requests.add(request);
            return request.future;
          },
          onOpenDetails: (_) {},
        ),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('Last available\n'), findsNWidgets(3));
    expect(requests, isEmpty);
    await tester.tap(find.byTooltip('Remove Charlie from comparison'));
    await tester.pump();
    expect(find.text('2 of 3 selected'), findsOneWidget);

    connection.setOnline(true);
    expect(requests, hasLength(2));
    connection.setOnline(false);
    connection.setOnline(true);
    expect(requests, hasLength(2));
    requests[0].complete(null);
    requests[1].complete(null);
    await tester.pump();
    expect(requests, hasLength(4));
    expect(controller.selection.every((item) => !item.isUnavailable), isTrue);

    requests[2].complete(
      Parking.fromMap(
        parkingData(id: 'Alpha', name: 'Alpha', availableCarSpaces: 3),
      ),
    );
    requests[3].complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsNothing);
    expect(find.text('3 of 20 (est.)'), findsOneWidget);
    expect(controller.selection.first.updatedAt, latest);
    expect(controller.selection.last.parking.name, 'Bravo');
    expect(controller.selection.last.isUnavailable, isTrue);
  });
}
