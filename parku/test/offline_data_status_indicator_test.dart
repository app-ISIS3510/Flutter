import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/widgets/offline_data_status_indicator.dart';

void main() {
  Widget buildTestWidget({required bool isFromCache, DateTime? updatedAt}) {
    return MaterialApp(
      home: Scaffold(
        body: OfflineDataStatusIndicator(
          isFromCache: isFromCache,
          updatedAt: updatedAt,
        ),
      ),
    );
  }

  testWidgets('Does not show indicator for network data', (tester) async {
    await tester.pumpWidget(buildTestWidget(isFromCache: false));

    expect(find.text('Saved data'), findsNothing);
    expect(find.textContaining('Last updated:'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
  });

  testWidgets('Shows cached data indicator without timestamp', (tester) async {
    await tester.pumpWidget(buildTestWidget(isFromCache: true));

    expect(find.text('Saved data'), findsOneWidget);
    expect(
      find.text('Showing locally stored information. It may be outdated.'),
      findsOneWidget,
    );
    expect(find.textContaining('Last updated:'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });

  testWidgets('Shows last update time when available', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isFromCache: true,
        updatedAt: DateTime(2026, 10, 30, 14, 45),
      ),
    );

    expect(find.text('Saved data'), findsOneWidget);
    expect(
      find.textContaining('Last updated: 2026-10-30 14:45'),
      findsOneWidget,
    );
  });
}
