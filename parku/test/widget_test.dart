import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/services/profile_service.dart';

import 'support/fake_user_repository.dart';

void main() {
  testWidgets(
    'Flow 3 edits the profile, validates plates and manages saved vehicles',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeUserRepository();
      final controller = ProfileController(ProfileService(repository));
      addTearDown(controller.dispose);
      int? nav;
      bool parkingOpened = false;
      bool signedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(
            controller: controller,
            onNavTap: (value) => nav = value,
            onMyParking: () => parkingOpened = true,
            onSignedOut: () => signedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alex Rivera'), findsOneWidget);
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Juan Rivera');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Rivera'), findsOneWidget);
      await tester.tap(find.text('My vehicles'));
      await tester.pumpAndSettle();
      expect(find.text('Add your first vehicle'), findsOneWidget);
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.ensureVisible(find.text('Save vehicle'));
      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a complete license plate to continue.'),
        findsOneWidget,
      );
      expect(repository.addCalls, 0);
      await tester.enterText(find.byType(TextFormField), 'abc123');
      await tester.pump();
      await tester.ensureVisible(find.text('Save vehicle'));
      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motorcycle'));
      await tester.enterText(find.byType(TextFormField), 'xyz45d');
      await tester.pump();
      await tester.ensureVisible(find.text('Save vehicle'));
      await tester.tap(find.text('Save vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use vehicle').last);
      await tester.pumpAndSettle();
      expect(controller.selectedVehicle?.plate, 'XYZ45D');
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('XYZ45D'), findsNothing);
      expect(controller.selectedVehicle?.plate, 'ABC123');
      await tester.tap(find.text('Check driving restrictions'));
      await tester.pumpAndSettle();
      expect(find.text('View official information'), findsOneWidget);
      await tester.tap(find.text('Change vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('Driving restrictions'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Add your first vehicle'), findsOneWidget);
      await tester.tap(find.text('Back to profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My parking'));
      expect(parkingOpened, true);
      await tester.tap(find.text('My favorites'));
      expect(nav, 2);
      await tester.ensureVisible(find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(signedOut, true);
      expect(controller.profile, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
