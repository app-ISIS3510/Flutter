import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
  });
  testWidgets(
    'Favorites can be removed and the empty state opens parking lots',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ParkUApp());
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNWidgets(4));
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Remove').first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Your favorites start here'), findsOneWidget);
      await tester.tap(find.text('Explore parking lots'));
      await tester.pumpAndSettle();
      expect(find.text('Find a place to park'), findsOneWidget);
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Your favorites start here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pickup time saves, cancels edits, and supports bottom navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ParkUApp());
      await tester.tap(find.text('Parking lots'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City U Parking'));
      await tester.pumpAndSettle();
      expect(find.text('When will you pick it up?'), findsOneWidget);
      await tester.tap(find.text('3:30'));
      await tester.pump();
      expect(find.text('3:30 PM'), findsOneWidget);
      await tester.ensureVisible(find.text('Start parking'));
      await tester.tap(find.text('Start parking'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('3:30 PM', findRichText: true),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Change pickup time'));
      await tester.tap(find.text('Change pickup time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4:30'));
      await tester.tap(find.text('Save pickup time'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4:30 PM', findRichText: true),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Change pickup time'));
      await tester.tap(find.text('Change pickup time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4:00'));
      await tester.tap(find.text('Back to my parking'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4:30 PM', findRichText: true),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Change pickup time'));
      await tester.tap(find.text('Change pickup time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNWidgets(4));
      expect(find.text('Need more time?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
