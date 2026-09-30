import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/screens/profile/profile_screen.dart';
import 'package:parku/screens/profile/edit_profile_screen.dart';
import 'package:parku/screens/profile/vehicles_screen.dart';
import 'package:parku/screens/profile/add_vehicle_screen.dart';
import 'package:parku/screens/profile/driving_restrictions_screen.dart';
import 'package:parku/services/profile_service.dart';
import 'package:parku/theme/app_theme.dart';
import 'package:parku/widgets/navigation_bar.dart';

import 'support/fake_user_repository.dart';

void main() {
  testWidgets('All ten Flow 3 designs fit Figma and small phone sizes', (
    tester,
  ) async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeUserRepository();
    final controller = ProfileController(ProfileService(repository));
    addTearDown(controller.dispose);
    const vehicle = Vehicle(
      id: 'car',
      type: VehicleType.car,
      plate: 'ABC123',
      isSelected: true,
    );
    for (final size in [const Size(390, 844), const Size(320, 568)]) {
      tester.view.physicalSize = size;
      for (int screen = 1; screen <= 10; screen++) {
        repository.vehicles = screen == 4 ? [] : [vehicle];
        await controller.load();
        final Widget page = switch (screen) {
          1 => ProfileScreen(
            controller: controller,
            onNavTap: (_) {},
            onMyParking: () {},
            onSignedOut: () {},
          ),
          2 => EditProfileScreen(controller: controller, onNavTap: (_) {}),
          3 || 4 => VehiclesScreen(controller: controller, onNavTap: (_) {}),
          8 || 9 => DrivingRestrictionsScreen(
            controller: controller,
            onNavTap: (_) {},
            now: DateTime.utc(2026, 9, screen == 8 ? 9 : 8, 12),
          ),
          _ => AddVehicleScreen(
            key: ValueKey(screen),
            controller: controller,
            onNavTap: (_) {},
          ),
        };
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Inter',
              scaffoldBackgroundColor: AppColors.background,
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: const EdgeInsets.only(top: 30, bottom: 14),
              ),
              child: RepaintBoundary(
                key: const ValueKey('screen'),
                child: page,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 6 || screen == 10) {
          await tester.tap(find.text('Motorcycle'));
          await tester.pumpAndSettle();
        }
        if (screen == 7 || screen == 10) {
          await tester.ensureVisible(find.text('Save vehicle'));
          await tester.tap(find.text('Save vehicle'));
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, 1000),
          );
          await tester.pumpAndSettle();
        }
        expect(find.byType(NavBar), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Screen $screen at $size',
        );
        if (const bool.fromEnvironment('FLOW3_PREVIEWS') && size.width == 390) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('screen')),
          );
          void repaint(RenderObject object) {
            object.markNeedsPaint();
            object.visitChildren(repaint);
          }

          repaint(boundary);
          await tester.pump();
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/flow3-review/flow3-$screen.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}
