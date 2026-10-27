import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/screens/pickup_time.dart';

void main() {
  const vehicle = Vehicle(
    id: 'moto-1',
    type: VehicleType.motorcycle,
    plate: 'ABC12D',
  );
  String? suggestion;
  String? started;

  Future<void> open(
    WidgetTester tester, {
    String? draft,
    DateTime? now,
    bool fail = false,
  }) async {
    suggestion = null;
    started = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PickupTimeScreen(
          vehicle: vehicle,
          onNavTap: (_) {},
          onChangeVehicle: () async => vehicle,
          openingTime: '08:00',
          closingTime: '22:00',
          currentTime: () => now ?? DateTime(2026, 10, 26, 12, 10),
          initialTime: draft,
          onSuggestionReady: (time) => suggestion = time,
          onStartParking: (time, _) async {
            started = time;
            if (fail) throw const SocketException('Offline');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Start parking'));
    await tester.tap(find.text('Start parking'));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.byType(DropdownButton<String>));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the visible suggestion is the default used to start parking', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Suggested pickup time: 12:30 PM'), findsOneWidget);
    await start(tester);
    expect(suggestion, '12:30');
    expect(started, suggestion);
  });

  testWidgets(
    'selecting another time leaves the original suggestion unchanged',
    (tester) async {
      await open(tester);
      await select(tester, '1:00 PM');
      await start(tester);
      expect(started, '13:00');
      expect(suggestion, '12:30');
    },
  );

  testWidgets(
    'returning to the suggested time counts as using that suggestion',
    (tester) async {
      await open(tester);
      await select(tester, '1:00 PM');
      await select(tester, '12:30 PM');
      await start(tester);
      expect(started, suggestion);
    },
  );

  testWidgets(
    'a restored manual draft is not reported as the suggestion after a failure',
    (tester) async {
      await open(tester, draft: '13:00', fail: true);
      await start(tester);
      expect(started, '13:00');
      expect(suggestion, '12:30');
      expect(find.text('Start parking'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        '13:00',
      );
    },
  );

  testWidgets('a closed parking lot provides no suggestion and cannot start', (
    tester,
  ) async {
    await open(tester, now: DateTime(2026, 10, 26, 22, 10));
    expect(suggestion, isNull);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(started, isNull);
  });
}
