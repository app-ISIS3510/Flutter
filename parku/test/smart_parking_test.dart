import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/parking_fakes.dart';

void main() {
  late GeolocatorPlatform original;
  late FakeLocationPlatform location;
  late SupabaseClient client;
  late ParkingController controller;
  late List<Map<String, dynamic>> rows;
  var requests = 0;
  var online = true;

  setUp(() {
    original = GeolocatorPlatform.instance;
    location = FakeLocationPlatform();
    GeolocatorPlatform.instance = location;
    rows = [parkingData()];
    requests = 0;
    online = true;
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests++;
        if (!online) throw http.ClientException('No connection');
        return http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    controller = ParkingController(
      ParkingService(ParkingRepository(client), DistanceManager()),
    );
  });

  tearDown(() async {
    GeolocatorPlatform.instance = original;
    await client.dispose();
  });

  test('keeps full lots visible without recommending them', () async {
    rows = [parkingData(availableCarSpaces: 0)];
    final results = await controller.loadSmartParkingResults(
      radiusMeters: 1000,
      vehicleType: SmartVehicleType.car,
    );
    expect(results.items.single.availableSpaces, 0);
    expect(results.items.single.isRecommended, isFalse);
  });

  test('ranks available lots by percentage, then distance, then ID', () async {
    rows = [
      parkingData(id: 'closest', latitude: 4.6001, availableCarSpaces: 1),
      parkingData(id: 'far', latitude: 4.603, availableCarSpaces: 15),
      parkingData(id: 'middle-b', latitude: 4.602, availableCarSpaces: 15),
      parkingData(id: 'middle-a', latitude: 4.602, availableCarSpaces: 15),
      parkingData(id: 'full', latitude: 4.6001, availableCarSpaces: 0),
    ];
    final results = await controller.loadSmartParkingResults(
      radiusMeters: 1000,
      vehicleType: SmartVehicleType.car,
    );
    expect(results.items.map((r) => r.parking.id), [
      'middle-a',
      'middle-b',
      'far',
      'closest',
      'full',
    ]);
    expect(
      results.items.where((r) => r.isRecommended).single.parking.id,
      'middle-a',
    );
  });

  test('applies the radius and the capacity of the selected vehicle', () async {
    rows = [
      parkingData(id: 'inside', latitude: 4.601),
      parkingData(id: 'outside', latitude: 4.61),
      parkingData(id: 'invalid', latitude: 95),
      parkingData(id: 'no-motorcycles', motorcycleSpaces: 0),
    ];
    final cars = await controller.loadSmartParkingResults(
      radiusMeters: 500,
      vehicleType: SmartVehicleType.car,
    );
    final motorcycles = await controller.loadSmartParkingResults(
      radiusMeters: 500,
      vehicleType: SmartVehicleType.motorcycle,
    );
    expect(cars.items.map((r) => r.parking.id), ['inside', 'no-motorcycles']);
    expect(cars.items.first.availabilityPercentage, 40);
    expect(motorcycles.items.map((r) => r.parking.id), ['inside']);
    expect(motorcycles.items.single.availabilityPercentage, 70);
  });

  test('refresh uses a new position and the latest capacity', () async {
    rows = [
      parkingData(id: 'north', latitude: 4.602),
      parkingData(id: 'south', latitude: 4.599),
    ];
    final first = await controller.loadSmartParkingResults(
      radiusMeters: 1000,
      vehicleType: SmartVehicleType.car,
    );
    expect(first.items.first.parking.id, 'south');
    location.latitude = 4.603;
    rows[0] = parkingData(id: 'north', latitude: 4.602, availableCarSpaces: 15);
    final second = await controller.loadSmartParkingResults(
      radiusMeters: 1000,
      vehicleType: SmartVehicleType.car,
    );
    expect(second.items.first.parking.id, 'north');
    expect(second.items.first.availableSpaces, 15);
    expect(location.positionCalls, 2);
    expect(requests, 2);
  });

  test(
    'denied GPS keeps the normal list without distances or recommendations',
    () async {
      location.permission = LocationPermission.denied;
      location.requestedPermission = LocationPermission.denied;
      rows = [
        parkingData(id: 'far', name: 'A distant lot', latitude: 4.65),
        parkingData(id: 'no-coordinates', name: 'B lot', latitude: null),
      ];
      final results = await controller.loadSmartParkingResults(
        radiusMeters: 500,
        vehicleType: SmartVehicleType.car,
      );
      expect(results.items.map((r) => r.parking.id), ['far', 'no-coordinates']);
      expect(results.locationNotice, contains('permission'));
      expect(
        results.locationNotice,
        contains('without distances or a radius filter'),
      );
      expect(results.items.every((r) => r.distanceMeters == null), isTrue);
      expect(results.items.every((r) => r.formattedDistance == null), isTrue);
      expect(results.items.every((r) => !r.isRecommended), isTrue);
    },
  );

  test(
    'disabled, permanently denied and timed-out GPS still allow browsing',
    () async {
      location.enabled = false;
      final disabled = await controller.loadSmartParkingResults(
        radiusMeters: 1000,
        vehicleType: SmartVehicleType.car,
      );
      expect(disabled.items, hasLength(1));
      expect(disabled.locationNotice, contains('turned off'));
      location.enabled = true;
      location.permission = LocationPermission.deniedForever;
      final denied = await controller.loadSmartParkingResults(
        radiusMeters: 1000,
        vehicleType: SmartVehicleType.car,
      );
      expect(denied.items, hasLength(1));
      expect(denied.locationNotice, contains('permission'));
      expect(location.permissionRequests, 0);
      location.permission = LocationPermission.whileInUse;
      location.failure = TimeoutException('Location timed out');
      final timedOut = await controller.loadSmartParkingResults(
        radiusMeters: 1000,
        vehicleType: SmartVehicleType.car,
      );
      expect(timedOut.items, hasLength(1));
      expect(timedOut.locationNotice, contains('Could not get your location'));
    },
  );

  test('does not turn a backend failure into a GPS fallback', () async {
    online = false;
    await expectLater(
      controller.loadSmartParkingResults(
        radiusMeters: 1000,
        vehicleType: SmartVehicleType.car,
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(location.positionCalls, 0);
  });

  test('empty data and invalid radii do not request a location', () async {
    rows = [];
    final empty = await controller.loadSmartParkingResults(
      radiusMeters: 1000,
      vehicleType: SmartVehicleType.car,
    );
    expect(empty.items, isEmpty);
    await expectLater(
      controller.loadSmartParkingResults(
        radiusMeters: 0,
        vehicleType: SmartVehicleType.car,
      ),
      throwsArgumentError,
    );
    expect(location.positionCalls, 0);
    expect(requests, 1);
  });

  test(
    'capacity values stay within limits and zero capacity is excluded',
    () async {
      rows = [
        parkingData(id: 'over-capacity', availableCarSpaces: 30),
        parkingData(id: 'negative-available', availableCarSpaces: -2),
        parkingData(id: 'zero-capacity', carSpaces: 0),
      ];
      final results = await controller.loadSmartParkingResults(
        radiusMeters: 1000,
        vehicleType: SmartVehicleType.car,
      );
      expect(results.items.map((r) => r.parking.id), [
        'over-capacity',
        'negative-available',
      ]);
      expect(results.items.first.availabilityPercentage, 100);
      expect(results.items.last.availabilityPercentage, 0);
      expect(results.items.last.isRecommended, isFalse);
    },
  );
}
