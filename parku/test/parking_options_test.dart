import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/controllers/parking_controller.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:parku/services/distance_manager.dart';
import 'package:parku/services/parking_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/parking_fakes.dart';

void main() {
  late GeolocatorPlatform originalPlatform;
  late FakeLocationPlatform location;
  late SupabaseClient client;
  late ParkingController controller;
  late List<Map<String, dynamic>> rows;
  late int requests;
  late int responseStatus;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    location = FakeLocationPlatform();
    GeolocatorPlatform.instance = location;
    rows = [parkingData()];
    requests = 0;
    responseStatus = 200;
    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/parking_lots_with_availability');
        requests++;
        return http.Response(
          jsonEncode(responseStatus == 200 ? rows : {'message': 'Unavailable'}),
          responseStatus,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    controller = ParkingController(
      ParkingService(ParkingRepository(client), DistanceManager()),
    );
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalPlatform;
    await client.dispose();
  });

  test(
    'returns every parking lot with its distance using one location fix',
    () async {
      rows = List.generate(
        6,
        (index) =>
            parkingData(id: 'parking-$index', latitude: 4.606 - index * 0.001),
      );

      final options = await controller.loadParkingOptions(
        vehicleType: VehicleType.car,
      );

      expect(options, hasLength(6));
      expect(options.first.parking.id, 'parking-5');
      expect(options.first.distanceMeters, closeTo(111.2, 1));
      expect(options.last.distanceMeters, closeTo(667.2, 2));
      expect(location.positionCalls, 1);
      expect(requests, 1);
    },
  );

  test('a new query uses the new phone location', () async {
    rows = [
      parkingData(id: 'north', latitude: 4.602),
      parkingData(id: 'south', latitude: 4.599),
    ];
    final first = await controller.loadParkingOptions();
    expect(first.first.parking.id, 'south');

    location.latitude = 4.603;
    final second = await controller.loadParkingOptions();
    expect(second.first.parking.id, 'north');
    expect(location.positionCalls, 2);
  });

  test('calculates car and motorcycle availability independently', () async {
    final cars = await controller.loadParkingOptions(
      vehicleType: VehicleType.car,
    );
    final motorcycles = await controller.loadParkingOptions(
      vehicleType: VehicleType.motorcycle,
    );

    expect(cars.single.vehicleType, VehicleType.car);
    expect(cars.single.availableSpaces, 8);
    expect(cars.single.totalSpaces, 20);
    expect(cars.single.availabilityRatio, 0.4);
    expect(cars.single.canBeRecommended, isTrue);
    expect(motorcycles.single.availableSpaces, 7);
    expect(motorcycles.single.totalSpaces, 10);
    expect(motorcycles.single.availabilityRatio, 0.7);
  });

  test('does not assume a vehicle when none is selected', () async {
    final option = (await controller.loadParkingOptions()).single;
    expect(option.distanceMeters, greaterThan(0));
    expect(option.vehicleType, isNull);
    expect(option.availableSpaces, isNull);
    expect(option.totalSpaces, isNull);
    expect(option.availabilityRatio, isNull);
    expect(option.canBeRecommended, isFalse);
  });

  test('ignores absent or invalid parking coordinates', () async {
    rows = [
      parkingData(id: 'valid'),
      parkingData(id: 'no-latitude', latitude: null),
      parkingData(id: 'no-longitude', longitude: null),
      parkingData(id: 'bad-latitude', latitude: 91),
      parkingData(id: 'bad-longitude', longitude: -181),
    ];
    final options = await controller.loadParkingOptions();
    expect(options.map((option) => option.parking.id), ['valid']);
  });

  test('does not request location when no parking has coordinates', () async {
    rows = [parkingData(latitude: null)];
    expect(await controller.loadParkingOptions(), isEmpty);
    expect(location.positionCalls, 0);
    rows = [];
    expect(await controller.loadParkingOptions(), isEmpty);
  });

  test(
    'keeps full lots visible but excludes them from recommendation eligibility',
    () async {
      rows = [parkingData(availableCarSpaces: 0)];
      final options = await controller.loadParkingOptions(
        vehicleType: VehicleType.car,
      );
      expect(options, hasLength(1));
      expect(options.single.availableSpaces, 0);
      expect(options.single.availabilityRatio, 0);
      expect(options.single.canBeRecommended, isFalse);
    },
  );

  test(
    'handles a vehicle type with no capacity without dividing by zero',
    () async {
      rows = [parkingData(motorcycleSpaces: 0)];
      final option = (await controller.loadParkingOptions(
        vehicleType: VehicleType.motorcycle,
      )).single;
      expect(option.totalSpaces, 0);
      expect(option.availableSpaces, 0);
      expect(option.availabilityRatio, 0);
      expect(option.canBeRecommended, isFalse);
    },
  );

  test('keeps availability inside the capacity limits', () async {
    rows = [parkingData(availableCarSpaces: 25, availableMotorcycleSpaces: -3)];
    final car = (await controller.loadParkingOptions(
      vehicleType: VehicleType.car,
    )).single;
    final motorcycle = (await controller.loadParkingOptions(
      vehicleType: VehicleType.motorcycle,
    )).single;
    expect(car.availableSpaces, 20);
    expect(car.availabilityRatio, 1);
    expect(motorcycle.availableSpaces, 0);
    expect(motorcycle.availabilityRatio, 0);

    rows = [parkingData(carSpaces: -1)];
    final invalid = (await controller.loadParkingOptions(
      vehicleType: VehicleType.car,
    )).single;
    expect(invalid.totalSpaces, 0);
    expect(invalid.availabilityRatio, 0);
  });

  test('reads updated availability on each query', () async {
    final before = await controller.loadParkingOptions(
      vehicleType: VehicleType.car,
    );
    rows = [parkingData(availableCarSpaces: 2)];
    final after = await controller.loadParkingOptions(
      vehicleType: VehicleType.car,
    );
    expect(before.single.availableSpaces, 8);
    expect(after.single.availableSpaces, 2);
    expect(after.single.availabilityRatio, 0.1);
  });

  test('preserves the existing four-nearest query', () async {
    rows = List.generate(
      6,
      (index) =>
          parkingData(id: 'parking-$index', latitude: 4.601 + index * 0.001),
    );
    final nearest = await controller.loadNearestParkingLots();
    expect(nearest.map((parking) => parking.id), [
      'parking-0',
      'parking-1',
      'parking-2',
      'parking-3',
    ]);
  });

  test('passes backend errors to the caller without requesting GPS', () async {
    responseStatus = 400;
    await expectLater(
      controller.loadParkingOptions(),
      throwsA(isA<PostgrestException>()),
    );
    expect(location.positionCalls, 0);
  });

  test(
    'requests location permission and uses a bounded high accuracy fix',
    () async {
      location.permission = LocationPermission.denied;
      await controller.loadParkingOptions();
      expect(location.permissionRequests, 1);
      expect(location.positionCalls, 1);
      expect(location.settings?.accuracy, LocationAccuracy.high);
      expect(location.settings?.timeLimit, const Duration(seconds: 20));
    },
  );

  test('reports disabled location services', () async {
    location.enabled = false;
    await expectLater(
      controller.loadParkingOptions(),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('Location services are disabled'),
        ),
      ),
    );
    expect(location.positionCalls, 0);
  });

  test('reports denied permission without reading the position', () async {
    location.permission = LocationPermission.denied;
    location.requestedPermission = LocationPermission.denied;
    await expectLater(
      controller.loadParkingOptions(),
      throwsA(
        predicate(
          (error) =>
              error.toString().contains('Location permission was denied'),
        ),
      ),
    );
    expect(location.positionCalls, 0);
  });

  test('does not request permanently denied permission again', () async {
    location.permission = LocationPermission.deniedForever;
    await expectLater(
      controller.loadParkingOptions(),
      throwsA(
        predicate((error) => error.toString().contains('permanently denied')),
      ),
    );
    expect(location.permissionRequests, 0);
    expect(location.positionCalls, 0);
  });

  test(
    'passes location timeouts to the caller without inventing distances',
    () async {
      location.failure = TimeoutException('Location timed out');
      await expectLater(
        controller.loadParkingOptions(),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
