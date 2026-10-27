import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/screens/pickup_time.dart';

const restrictedCar = Vehicle(
  id: 'car-6',
  type: VehicleType.car,
  plate: 'ABC126',
);
const allowedCar = Vehicle(id: 'car-3', type: VehicleType.car, plate: 'ABC123');

Future<void> openPickup(
  WidgetTester tester, {
  Vehicle vehicle = restrictedCar,
  DateTime Function()? currentTime,
  Future<void> Function(String, Vehicle)? onStart,
  Future<Vehicle?> Function()? onChange,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: PickupTimeScreen(
        vehicle: vehicle,
        onNavTap: (_) {},
        onChangeVehicle: onChange ?? () async => vehicle,
        onStartParking: onStart ?? (_, _) async {},
        openingTime: '00:00',
        closingTime: '23:59',
        currentTime: currentTime ?? () => DateTime.utc(2026, 10, 9, 15),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pressStart(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Start parking'));
  await tester.tap(find.text('Start parking'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a restricted car needs acknowledgement before starting parking',
    (tester) async {
      Vehicle? startedVehicle;
      await openPickup(
        tester,
        onStart: (_, vehicle) async => startedVehicle = vehicle,
      );
      await pressStart(tester);
      expect(find.text('Pico y placa today'), findsOneWidget);
      expect(
        find.textContaining('ABC126 has driving restrictions'),
        findsOneWidget,
      );
      expect(find.textContaining('9/10/2026'), findsOneWidget);
      expect(find.textContaining('6:00 AM–9:00 PM'), findsOneWidget);
      expect(startedVehicle, isNull);

      await tester.tap(find.text('Continue parking'));
      await tester.pumpAndSettle();
      expect(startedVehicle?.id, restrictedCar.id);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'cancelling the notice does not create a session and allows retry',
    (tester) async {
      var starts = 0;
      await openPickup(tester, onStart: (_, _) async => starts++);
      await pressStart(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(starts, 0);
      expect(find.text('Start parking'), findsOneWidget);
      await pressStart(tester);
      expect(find.text('Pico y placa today'), findsOneWidget);
      expect(starts, 0);
    },
  );

  testWidgets('an unrestricted vehicle starts without a warning', (
    tester,
  ) async {
    var starts = 0;
    await openPickup(
      tester,
      vehicle: allowedCar,
      onStart: (_, _) async => starts++,
    );
    await pressStart(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(starts, 1);
  });

  testWidgets('closing the notice with back does not start parking', (
    tester,
  ) async {
    var starts = 0;
    await openPickup(tester, onStart: (_, _) async => starts++);
    await pressStart(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(starts, 0);
    expect(find.text('Start parking'), findsOneWidget);
  });

  testWidgets(
    'the warning uses the vehicle selected after opening the screen',
    (tester) async {
      Vehicle? startedVehicle;
      await openPickup(
        tester,
        vehicle: allowedCar,
        onChange: () async => restrictedCar,
        onStart: (_, vehicle) async => startedVehicle = vehicle,
      );
      await tester.tap(find.text('Change vehicle'));
      await tester.pumpAndSettle();
      await pressStart(tester);
      expect(
        find.textContaining('ABC126 has driving restrictions'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue parking'));
      await tester.pumpAndSettle();
      expect(startedVehicle?.id, restrictedCar.id);
    },
  );

  testWidgets(
    'switching to an unrestricted vehicle removes the need for a notice',
    (tester) async {
      Vehicle? startedVehicle;
      await openPickup(
        tester,
        onChange: () async => allowedCar,
        onStart: (_, vehicle) async => startedVehicle = vehicle,
      );
      await tester.tap(find.text('Change vehicle'));
      await tester.pumpAndSettle();
      await pressStart(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(startedVehicle?.id, allowedCar.id);
    },
  );

  testWidgets('checks the current date when the user presses start', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 8, 15);
    await openPickup(tester, currentTime: () => now);
    now = DateTime.utc(2026, 10, 9, 15);
    await pressStart(tester);
    expect(find.text('Pico y placa today'), findsOneWidget);
    expect(find.textContaining('9/10/2026'), findsOneWidget);
  });

  testWidgets(
    'an unsupported date shows an unknown status instead of no restriction',
    (tester) async {
      var starts = 0;
      await openPickup(
        tester,
        currentTime: () => DateTime.utc(2027, 10, 8, 15),
        onStart: (_, _) async => starts++,
      );
      await pressStart(tester);
      expect(find.text('Check driving restrictions'), findsOneWidget);
      expect(find.textContaining('We could not confirm'), findsOneWidget);
      expect(starts, 0);
    },
  );

  testWidgets(
    'repeated taps do not duplicate the notice or the parking request',
    (tester) async {
      var starts = 0;
      final response = Completer<void>();
      await openPickup(
        tester,
        onStart: (_, _) {
          starts++;
          return response.future;
        },
      );
      await tester.ensureVisible(find.text('Start parking'));
      await tester.tap(find.text('Start parking'));
      await tester.tap(find.text('Start parking'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Continue parking'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.text('Starting parking...'), findsOneWidget);
      response.complete();
      await tester.pumpAndSettle();
      expect(starts, 1);
    },
  );

  testWidgets('a failed parking request shows an error and allows retry', (
    tester,
  ) async {
    await openPickup(
      tester,
      onStart: (_, _) async => throw Exception('offline'),
    );
    await pressStart(tester);
    await tester.tap(find.text('Continue parking'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not complete this request. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    await pressStart(tester);
    expect(find.text('Pico y placa today'), findsOneWidget);
  });

  testWidgets('the notice fits a small phone', (tester) async {
    await openPickup(tester);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    await pressStart(tester);
    expect(find.text('Continue parking'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue parking'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
