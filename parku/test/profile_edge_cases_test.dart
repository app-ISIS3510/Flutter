import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/services/driving_restriction_service.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/screens/profile/driving_restrictions_screen.dart';
import 'package:parku/screens/profile/edit_profile_screen.dart';
import 'package:parku/screens/pickup_time.dart';

import 'support/fake_user_repository.dart';

class UnavailableVehicles extends FakeUserRepository {
  @override
  Future<List<Vehicle>> getVehicles() async => throw Exception('offline');
}

class DelayedSignOut extends FakeUserRepository {
  final pending = Completer<void>();
  @override
  Future<void> signOut() => pending.future;
}

void main() {
  const car = Vehicle(
    id: 'car',
    type: VehicleType.car,
    plate: 'ABC123',
    isSelected: true,
  );
  const moto = Vehicle(
    id: 'moto',
    type: VehicleType.motorcycle,
    plate: 'XYZ45D',
    isSelected: true,
  );
  testWidgets(
    'a vehicle loading error does not hide the profile or sign-out button',
    (tester) async {
      final controller = ProfileController(
        ProfileService(UnavailableVehicles()),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            controller: controller,
            onNavTap: (_) {},
            onMyParking: () {},
            onSignedOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );
  test('a late sign-out response does not erase a new account', () async {
    final repo = DelayedSignOut();
    final controller = ProfileController(ProfileService(repo));
    addTearDown(controller.dispose);
    await controller.load();
    final signingOut = controller.signOut();
    controller.clear();
    repo.profile = const UserProfile(
      id: 'user-2',
      fullName: 'Another user',
      email: 'other@example.com',
    );
    await controller.load();
    repo.pending.complete();
    expect(await signingOut, false);
    expect(controller.profile?.id, 'user-2');
  });
  testWidgets('pickup clears a deleted vehicle and accepts a replacement', (
    tester,
  ) async {
    Vehicle? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: PickupTimeScreen(
          onNavTap: (_) {},
          onStartParking: (_, _) async {},
          vehicle: car,
          onChangeVehicle: () async => chosen,
          openingTime: '00:00',
          closingTime: '23:59',
        ),
      ),
    );
    await tester.tap(find.text('Change vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('ABC123'), findsNothing);
    expect(find.text('No vehicle selected'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Start parking'))
          .onPressed,
      isNull,
    );
    chosen = moto;
    await tester.tap(find.text('Change vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('XYZ45D'), findsOneWidget);
    expect(find.text('Motorcycle'), findsOneWidget);
  });
  testWidgets(
    'official information opens the correct URL and handles launcher failure',
    (tester) async {
      final repo = FakeUserRepository()..vehicles = [car];
      final controller = ProfileController(ProfileService(repo));
      addTearDown(controller.dispose);
      await controller.load();
      MethodCall? launched;
      bool canOpen = true;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        launched = call;
        return canOpen;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DrivingRestrictionsScreen(
            controller: controller,
            onNavTap: (_) {},
            now: DateTime.utc(2026, 9, 9, 12),
          ),
        ),
      );
      await tester.tap(find.text('View official information'));
      await tester.pumpAndSettle();
      expect(launched?.arguments['url'], DrivingRestrictionService.officialUrl);
      canOpen = false;
      await tester.tap(find.text('View official information'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the official website. Please try again.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'edit profile remains usable on a small phone with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final controller = ProfileController(
        ProfileService(FakeUserRepository()),
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          home: EditProfileScreen(controller: controller, onNavTap: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your full name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
