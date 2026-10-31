import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/pickup_choice_summary.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/screens/pickup_time.dart';

void main() {
  const vehicle = Vehicle(
    id: 'moto-1',
    type: VehicleType.motorcycle,
    plate: 'ABC12D',
  );
  var started = false;

  PickupChoiceSummary summary({bool cached = false, int count = 2}) =>
      PickupChoiceSummary(
        suggested: count,
        manual: count == 0 ? 0 : 1,
        notRecorded: count == 0 ? 0 : 1,
        suggestedPercentage: count == 0 ? 0 : 50,
        manualPercentage: count == 0 ? 0 : 25,
        notRecordedPercentage: count == 0 ? 0 : 25,
        updatedAt: DateTime(2026, 10, 30, 14, 5),
        isFromCache: cached,
      );

  Future<void> open(
    WidgetTester tester,
    Future<PickupChoiceSummary> Function() load, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    started = false;
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
        home: PickupTimeScreen(
          vehicle: vehicle,
          onNavTap: (_) {},
          onChangeVehicle: () async => vehicle,
          openingTime: '08:00',
          closingTime: '22:00',
          currentTime: () => DateTime(2026, 10, 29, 12, 10),
          loadPickupChoices: load,
          onStartParking: (_, _) async => started = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start parking'));
    await tester.tap(find.text('Start parking'));
    await tester.pumpAndSettle();
    expect(started, isTrue);
  }

  for (final size in [const Size(320, 568), const Size(640, 360)]) {
    testWidgets('pickup results fit at $size with large text', (tester) async {
      await open(tester, () async => summary(), size: size, textScale: 2);
      await tester.ensureVisible(find.text('Pickup time choices'));
      expect(find.text('50.00%'), findsOneWidget);
      expect(find.text('25.00%'), findsNWidgets(2));
      expect(
        find.text('Based on 4 successful parking starts.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await start(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading the statistics does not block parking', (tester) async {
    final response = Completer<PickupChoiceSummary>();
    await open(tester, () => response.future);
    expect(find.text('Loading pickup choices...'), findsOneWidget);
    await start(tester);
    response.complete(summary());
    await tester.pumpAndSettle();
  });

  testWidgets('retrying after a failure keeps the chosen pickup time', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, () async {
      calls++;
      if (calls == 1) throw StateError('Unavailable');
      return summary();
    });
    await tester.ensureVisible(find.byType(DropdownButton<String>));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1:00 PM').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry results'));
    await tester.tap(find.text('Retry results'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('50.00%'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      '13:00',
    );
    await start(tester);
  });

  testWidgets('unavailable analytics does not block parking', (tester) async {
    await open(tester, () async => throw StateError('Unavailable'));
    expect(
      find.text('Pickup choices are unavailable. You can still choose a time.'),
      findsOneWidget,
    );
    await start(tester);
  });

  testWidgets('saved results show their original date and period', (
    tester,
  ) async {
    await open(tester, () async => summary(cached: true));
    expect(find.text('Saved results · 7-day period'), findsOneWidget);
    expect(
      find.text('Saved on 30/10/2026 14:05. Connect to update.'),
      findsOneWidget,
    );
    expect(find.text('Successful parking starts · Last 7 days'), findsNothing);
  });

  testWidgets('an empty week shows a message instead of fake percentages', (
    tester,
  ) async {
    await open(tester, () async => summary(count: 0));
    expect(
      find.text('No parking starts were recorded in this period.'),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    await start(tester);
  });
}
