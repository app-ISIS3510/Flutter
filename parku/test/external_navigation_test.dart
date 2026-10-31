import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku/adapters/navigation_adapter.dart';
import 'package:parku/controllers/navigation_controller.dart';
import 'package:parku/models/navigation_provider.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/services/connectivity_service.dart';
import 'package:parku/services/navigation_service.dart';
import 'package:parku/widgets/external_navigation.dart';

import 'support/parking_fakes.dart';

class NavigationConnection extends ConnectivityService {
  bool online = false;
  @override
  Future<bool> hasNetworkConnection() async => online;
}

class RecordingNavigation extends NavigationAdapter {
  final locations = <(double, double)>[];
  @override
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  }) async => locations.add((latitude, longitude));
}

void main() {
  late RecordingNavigation maps;
  late RecordingNavigation waze;
  late NavigationConnection connection;
  late NavigationController controller;
  NavigationProvider? result;
  final parking = Parking.fromMap(parkingData());

  setUp(() {
    maps = RecordingNavigation();
    waze = RecordingNavigation();
    connection = NavigationConnection();
    controller = NavigationController(
      NavigationService(
        googleMapsAdapter: maps,
        wazeAdapter: waze,
        connectivityService: connection,
      ),
    );
    result = null;
  });

  Future<void> open(WidgetTester tester, NavigationProvider provider) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await openExternalNavigation(
                context: context,
                controller: controller,
                provider: provider,
                parking: parking,
              ),
              child: const Text('Directions'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Directions'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'short offline warning fits a small screen and cancel opens nothing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, NavigationProvider.googleMaps);
      expect(find.text("You're offline"), findsOneWidget);
      expect(
        find.text('Google Maps may need internet for directions.'),
        findsOneWidget,
      );
      expect(maps.locations, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(maps.locations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final provider in NavigationProvider.values) {
    testWidgets('offline ${provider.label} opens only after confirmation', (
      tester,
    ) async {
      await open(tester, provider);
      expect(maps.locations, isEmpty);
      expect(waze.locations, isEmpty);
      await tester.tap(find.text('Open anyway'));
      await tester.pumpAndSettle();
      expect(result, provider);
      final adapter = provider == NavigationProvider.googleMaps ? maps : waze;
      expect(adapter.locations.single, (parking.latitude, parking.longitude));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'copy keeps the full address and coordinates despite the shorter dialog',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, NavigationProvider.waze);
      await tester.tap(find.text('Copy location'));
      await tester.pumpAndSettle();
      expect(copied, contains(parking.address));
      expect(copied, contains('${parking.latitude}, ${parking.longitude}'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(waze.locations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
