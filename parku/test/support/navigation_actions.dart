import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/widgets/navigation_bar.dart';

Future<void> tapNavigation(WidgetTester tester, String label) async {
  // Connection notices can cover the bottom bar during these flows.
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pumpAndSettle();
  final target = find
      .descendant(of: find.byType(NavBar).last, matching: find.text(label))
      .hitTestable();
  expect(target, findsOneWidget);
  await tester.tap(target);
  await tester.pumpAndSettle();
}
