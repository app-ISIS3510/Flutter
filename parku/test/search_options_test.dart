import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/screens/search.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/data/local/parking_local_data_source.dart';

import 'support/parking_fakes.dart';

class TestParkingLocalDataSource extends ParkingLocalDataSource {
  @override
  Future<CachedParkingList?> readParkingLots() async => null;

  @override
  Future<CachedParkingList?> readParkingForNearby() async => null;

  @override
  Future<void> saveParkingLots(List<Parking> parkingLots) async {}
}

void main() {
  late GeolocatorPlatform originalPlatform;
  late FakeLocationPlatform location;
  late SupabaseClient client;
  late ParkingController controller;
  late List<String> searches;

  const car = Vehicle(
    id: 'car-1',
    type: VehicleType.car,
    plate: 'ABC123',
    isSelected: true,
  );
  const motorcycle = Vehicle(
    id: 'moto-1',
    type: VehicleType.motorcycle,
    plate: 'XYZ45D',
    isSelected: true,
  );

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    location = FakeLocationPlatform();
    GeolocatorPlatform.instance = location;
    searches = [];
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([parkingData()]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    controller = ParkingController(
      ParkingService(
        ParkingRepository(
          client,
          localDataSource: TestParkingLocalDataSource(),
        ),
        DistanceManager(),
      ),
    );
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalPlatform;
    await client.dispose();
  });

  Widget search({Vehicle? vehicle = car}) => MaterialApp(
    home: SearchScreen(
      parkingController: controller,
      selectedVehicle: vehicle,
      currentIndex: 1,
      onNavTap: (_) {},
      onSearch: searches.add,
    ),
  );

  testWidgets(
    'shows availability for the selected vehicle and preserves search',
    (tester) async {
      await tester.pumpWidget(search());
      await tester.pumpAndSettle();
      expect(find.text('Availability for your car · ABC123'), findsOneWidget);
      expect(find.text('8 estimated spaces · 40% of capacity'), findsOneWidget);

      await tester.tap(find.text('City U Parking'));
      expect(searches, ['City U Parking']);
      await tester.enterText(find.byType(TextField), 'Library');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(searches.last, 'Library');
    },
  );

  testWidgets('does not reacquire GPS on parent rebuild or text entry', (
    tester,
  ) async {
    await tester.pumpWidget(search());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'City');
    await tester.pumpWidget(search());
    await tester.pumpAndSettle();
    expect(location.positionCalls, 1);
  });

  testWidgets('recalculates availability after changing the selected vehicle', (
    tester,
  ) async {
    await tester.pumpWidget(search());
    await tester.pumpAndSettle();
    await tester.pumpWidget(search(vehicle: motorcycle));
    await tester.pumpAndSettle();
    expect(
      find.text('Availability for your motorcycle · XYZ45D'),
      findsOneWidget,
    );
    expect(find.text('7 estimated spaces · 70% of capacity'), findsOneWidget);
    expect(find.text('8 estimated spaces · 40% of capacity'), findsNothing);
    expect(location.positionCalls, 2);
  });

  testWidgets(
    'allows browsing without assuming a car for users with no vehicle',
    (tester) async {
      await tester.pumpWidget(search(vehicle: null));
      await tester.pumpAndSettle();
      expect(
        find.text('Select a vehicle in Profile to see its availability.'),
        findsOneWidget,
      );
      expect(find.text('City U Parking'), findsOneWidget);
      expect(find.textContaining('estimated spaces'), findsNothing);
    },
  );

  testWidgets('reports location errors while keeping name search usable', (
    tester,
  ) async {
    location.enabled = false;
    await tester.pumpWidget(search());
    await tester.pumpAndSettle();
    expect(
      find.text('Turn on your device location to find nearby parking lots.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Library');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(searches, ['Library']);
  });

  testWidgets('reports location timeouts instead of leaving a spinner', (
    tester,
  ) async {
    location.failure = TimeoutException('Location timed out');
    await tester.pumpWidget(search());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not get your location. Check your GPS and reopen search.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('fits a small phone with the availability text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(search(vehicle: motorcycle));
    await tester.pumpAndSettle();
    expect(find.text('7 estimated spaces · 70% of capacity'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
