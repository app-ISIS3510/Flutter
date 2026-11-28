import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/navigation_controller.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/screens/my_parking.dart';
import 'package:parku/services/navigation_service.dart';

Widget parkingScreen({
  required DateTime pickupTime,
  required DateTime Function() currentTime,
}) {
  return MaterialApp(
    home: MyParkingScreen(
      currentIndex: 0,
      onNavTap: (_) {},
      onEndParking: () async => null,
      currentTime: currentTime,
      navigationController: NavigationController(NavigationService.create()),
      session: ParkingSession(
        id: 'session-1',
        parkingId: 'parking-1',
        pickupTime: pickupTime,
        startedAt: pickupTime.subtract(const Duration(hours: 2)),
        status: 'active',
      ),
      parking: Parking(
        id: 'parking-1',
        name: 'City U Parking',
        address: 'Calle 20',
        pricePerMinute: 100,
        carSpaces: 1,
        motorcycleSpaces: 1,
        availableCarSpaces: 1,
        availableMotorcycleSpaces: 1,
      ),
    ),
  );
}

void main() {
  testWidgets('the visible minute changes without rebuilding My Parking', (
    tester,
  ) async {
    final clock = tester.binding.clock;
    var clockReads = 0;
    await tester.pumpWidget(
      parkingScreen(
        pickupTime: clock.now().add(const Duration(hours: 1, seconds: 5)),
        currentTime: () {
          clockReads++;
          return clock.now();
        },
      ),
    );
    expect(find.text('01:00'), findsOneWidget);
    expect(clockReads, 1);

    var screenRebuilds = 0;
    final previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousCallback?.call(element, builtOnce);
      if (element.widget is MyParkingScreen) screenRebuilds++;
    };
    try {
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('01:00'), findsOneWidget);
      expect(clockReads, 1);

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('00:59'), findsOneWidget);
      expect(clockReads, 2);

      await tester.pump(const Duration(minutes: 1));
      expect(find.text('00:58'), findsOneWidget);
      expect(clockReads, 3);
      expect(screenRebuilds, 0);
    } finally {
      debugOnRebuildDirtyWidget = previousCallback;
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the countdown recalculates after a pickup change and on resume',
    (tester) async {
      final binding = tester.binding;
      final clock = binding.clock;
      final currentTime = clock.now;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        parkingScreen(
          pickupTime: currentTime().add(const Duration(minutes: 10)),
          currentTime: currentTime,
        ),
      );
      expect(find.text('00:10'), findsOneWidget);

      await tester.pumpWidget(
        parkingScreen(
          pickupTime: currentTime().add(const Duration(minutes: 3, seconds: 5)),
          currentTime: currentTime,
        ),
      );
      expect(find.text('00:03'), findsOneWidget);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 1, seconds: 10));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('00:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 56));
      expect(find.text('00:00'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('00:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
