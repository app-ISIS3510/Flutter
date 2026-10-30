import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/screens/change_pickup_time.dart';
import 'package:parku/screens/end_parking.dart';
import 'package:parku/screens/pickup_time.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/services/connection_failure.dart';
import 'package:parku/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/offline_fakes.dart';

void main() {
  late SupabaseClient client;
  late UnstableUserRepository remote;
  late ProfileController controller;
  const vehicle = Vehicle(
    id: 'vehicle-1',
    type: VehicleType.car,
    plate: 'ABC123',
    isSelected: true,
  );

  setUp(() async {
    client = offlineTestClient();
    await signInAs(client, 'user-1');
    remote = UnstableUserRepository();
    await remote.addVehicle(VehicleType.car, 'ABC123');
    remote.writes = 0;
    controller = ProfileController(
      ProfileService(remote, store: UserLocalStore.memory(client)),
    );
    await controller.load();
    remote.online = false;
  });
  tearDown(() async {
    controller.dispose();
    await client.dispose();
  });

  testWidgets(
    'profile and vehicles stay navigable with saved data while offline',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            controller: controller,
            onNavTap: (_) {},
            onMyParking: () {},
            onAnalyticsDashboard: () {},
            onSignedOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.textContaining('Showing saved information'), findsOneWidget);
      await tester.ensureVisible(find.text('My vehicles'));
      await tester.tap(find.text('My vehicles'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      await tester.ensureVisible(find.text('Use vehicle'));
      await tester.tap(find.text('Use vehicle'));
      await tester.pumpAndSettle();
      expect(remote.writes, 0);
      expect(find.text('ABC123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a failed pickup request keeps its time and provides a status check',
    (tester) async {
      var checked = false;
      String? savedDraft;
      await tester.pumpWidget(
        MaterialApp(
          home: PickupTimeScreen(
            vehicle: vehicle,
            onNavTap: (_) {},
            onChangeVehicle: () async => vehicle,
            openingTime: '06:00',
            closingTime: '22:00',
            currentTime: () => DateTime(2026, 10, 26, 12),
            initialTime: '16:00',
            onDraftChanged: (time, _) => savedDraft = time,
            onStartParking: (_, _) async =>
                throw const ConnectionFailure('The request is not confirmed.'),
            onCheckStatus: () => checked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4:30 PM').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start parking'));
      await tester.tap(find.text('Start parking'));
      await tester.pumpAndSettle();
      if (find.text('Continue parking').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continue parking'));
        await tester.pumpAndSettle();
      }

      expect(savedDraft, '16:30');
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        '16:30',
      );
      await tester.ensureVisible(find.text('Check My parking'));
      await tester.tap(find.text('Check My parking'));
      expect(checked, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an offline time change stays open with the chosen draft', (
    tester,
  ) async {
    String? savedDraft;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePickupTimeScreen(
          initialTime: '16:00',
          openingTime: '06:00',
          closingTime: '22:00',
          currentTime: () => DateTime(2026, 10, 26, 12),
          onNavTap: (_) {},
          onDraftChanged: (time) => savedDraft = time,
          onSave: (_) async => throw const SocketException('Offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4:30 PM').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save pickup time'));
    await tester.tap(find.text('Save pickup time'));
    await tester.pumpAndSettle();

    expect(savedDraft, '16:30');
    expect(find.byType(ChangePickupTimeScreen), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .value,
      '16:30',
    );
    expect(
      find.text('We could not update your pickup time. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'end parking fits a small phone and stays open on an uncertain response',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: EndParkingScreen(
            currentIndex: 3,
            onNavTap: (_) {},
            onConfirmEndParking: () async => throw const ConnectionFailure(
              'The end request is not confirmed.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("Yes, I've picked it up"));
      await tester.tap(find.text("Yes, I've picked it up"));
      await tester.pumpAndSettle();

      expect(find.byType(EndParkingScreen), findsOneWidget);
      expect(find.text('The end request is not confirmed.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
