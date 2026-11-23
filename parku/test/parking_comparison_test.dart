import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/parking_comparison_controller.dart';
import 'package:parku/controllers/parking_controller.dart';
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
    expect(controller.selection, lots.take(3));

    controller.toggle(lots.first);
    controller.toggle(lots.last);
    expect(controller.selection, lots.skip(1));
  });

  testWidgets('selects from search, compares and removes on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ParkingComparisonController();
    addTearDown(controller.dispose);
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
}
