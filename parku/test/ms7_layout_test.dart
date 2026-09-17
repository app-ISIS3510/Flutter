import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/screens/pickup_time.dart';
import 'package:parku/screens/change_pickup_time.dart';
import 'package:parku/screens/favorites.dart';
import 'package:parku/screens/no_favorites.dart';
import 'package:parku/theme/app_theme.dart';

void main() {
  testWidgets('Render the four MS7 screens at Figma size and a small phone', (
    tester,
  ) async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screens = <String, Widget>{
      'pickup_time': PickupTimeScreen(onNavTap: (_) {}, onStartParking: (_) {}),
      'change_pickup_time': ChangePickupTimeScreen(
        onNavTap: (_) {},
        onSave: (_) {},
      ),
      'favorites': FavoritesScreen(
        onNavTap: (_) {},
        onRemove: (_) {},
        favorites: const [
          {'name': 'City U Parking', 'address': 'Calle 20 · Las Aguas, Bogotá'},
          {'name': 'MetroPark Center', 'address': '45 Market St'},
          {'name': 'University Lot C', 'address': '102 Campus Drive'},
          {'name': 'Library Underground', 'address': '250 Civic Center'},
        ],
      ),
      'no_favorites': NoFavoritesScreen(onNavTap: (_) {}),
    };
    for (final size in [const Size(390, 844), const Size(320, 568)]) {
      tester.view.physicalSize = size;
      for (final entry in screens.entries) {
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
                child: entry.value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
