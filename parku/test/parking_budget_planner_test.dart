import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/screens/parking_budget_planner.dart';
import 'package:parku/state/parking_detail_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/parking_fakes.dart';

Future<void> openPlanner(
  WidgetTester tester, {
  String userId = 'user-1',
  double rate = 120,
  bool savedRate = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ParkingBudgetPlannerScreen(
        key: ValueKey(userId),
        userId: userId,
        details: ParkingDetailState(
          parking: Parking.fromMap({
            ...parkingData(),
            'price_per_minute': rate,
          }),
          isFromCache: savedRate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('calculates with a saved rate and restores the plan per user', (
    tester,
  ) async {
    await openPlanner(tester, savedRate: true);
    expect(find.text('Saved parking rate'), findsOneWidget);

    final fields = find.byType(TextFormField);
    final calculate = find.text('Calculate estimate');
    await tester.enterText(fields.at(0), '90');
    await tester.enterText(fields.at(1), '12000');
    await tester.ensureVisible(calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(find.text('Estimated cost: COP 10,800'), findsOneWidget);
    expect(find.text('Within budget'), findsOneWidget);

    await tester.ensureVisible(fields.at(1));
    await tester.enterText(fields.at(1), '10000');
    await tester.pumpAndSettle();
    expect(find.text('Within budget'), findsNothing);
    await tester.ensureVisible(calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    expect(find.text('Over budget'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await openPlanner(tester, userId: 'user-2');
    expect(find.text('90'), findsNothing);
    expect(find.text('10000'), findsNothing);
    await openPlanner(tester, userId: 'user-1');
    expect(find.text('90'), findsOneWidget);
    expect(find.text('10000'), findsOneWidget);
  });

  testWidgets('does not show a zero estimate when the rate is missing', (
    tester,
  ) async {
    await openPlanner(tester, rate: 0, savedRate: true);

    expect(
      find.text('No rate is available to estimate the cost.'),
      findsOneWidget,
    );
    expect(find.text('Calculate estimate'), findsNothing);
  });
}
