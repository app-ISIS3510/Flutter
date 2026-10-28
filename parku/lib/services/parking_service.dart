import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/parking.dart';
import '../models/most_used_parking.dart';
import '../models/parking_option.dart';
import '../models/smart_parking_result.dart';
import '../models/vehicle.dart';
import '../repositories/parking_repository.dart';
import 'distance_manager.dart';

enum SmartVehicleType { car, motorcycle }

class ParkingService {
  final ParkingRepository repository;
  final DistanceManager distanceManager;

  ParkingService(this.repository, this.distanceManager);

  Future<List<MostUsedParking>> getMostUsedParkingLots() {
    return repository.getMostUsedParkingLots().timeout(
      const Duration(seconds: 8),
    );
  }

  Future<List<Parking>> getParkingLots() {
    return repository.getParkingLots();
  }

  Future<Parking?> getParkingById(String id) {
    return repository.getParkingById(id);
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return repository.searchParkingLots(query);
  }

  Future<List<Parking>> getNearestParkingLots({int limit = 4}) async {
    final options = await getParkingOptions();
    return options.take(limit).map((option) => option.parking).toList();
  }

  Future<List<ParkingOption>> getParkingOptions({
    VehicleType? vehicleType,
  }) async {
    final parkingLots = await repository.getParkingLots();

    final parkingWithLocation = parkingLots.where((parking) {
      return _hasValidCoordinates(parking);
    }).toList();

    if (parkingWithLocation.isEmpty) return [];

    final position = await distanceManager.getCurrentPosition();

    final options = parkingWithLocation.map((parking) {
      return ParkingOption(
        parking: parking,
        distanceMeters: distanceManager.calculateDistance(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          parkingLatitude: parking.latitude!,
          parkingLongitude: parking.longitude!,
        ),
        vehicleType: vehicleType,
      );
    }).toList();

    options.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return options;
  }

  bool _hasValidCoordinates(Parking parking) {
    final latitude = parking.latitude;
    final longitude = parking.longitude;

    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  Future<SmartParkingResults> getSmartParkingResults({
    required int radiusMeters,
    required SmartVehicleType vehicleType,
  }) async {
    if (radiusMeters <= 0) {
      throw ArgumentError('Radius must be greater than zero.');
    }

    final parkingLots = await repository.getParkingLots().timeout(
      const Duration(seconds: 12),
    );
    if (parkingLots.isEmpty) return const SmartParkingResults(items: []);

    Position? position;
    String? locationNotice;
    try {
      position = await distanceManager.getCurrentPosition();
    } catch (error) {
      var reason = 'Could not get your location.';
      final message = error.toString();
      if (message.contains('permission')) {
        reason = 'Location permission is not enabled.';
      } else if (message.contains('disabled')) {
        reason = 'Location services are turned off.';
      }
      locationNotice =
          '$reason Showing parking lots without distances or a '
          'radius filter. Enable location and tap Refresh location to search nearby.';
    }

    final results = <SmartParkingResult>[];

    for (final parking in parkingLots) {
      if (position != null && !_hasValidCoordinates(parking)) continue;

      final totalSpaces = vehicleType == SmartVehicleType.car
          ? parking.carSpaces
          : parking.motorcycleSpaces;

      final availableSpaces = vehicleType == SmartVehicleType.car
          ? parking.availableCarSpaces
          : parking.availableMotorcycleSpaces;

      if (totalSpaces <= 0) continue;

      double? distance;
      if (position != null) {
        distance = distanceManager.calculateDistance(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          parkingLatitude: parking.latitude!,
          parkingLongitude: parking.longitude!,
        );
        if (!distance.isFinite || distance > radiusMeters) continue;
      }

      final validAvailable = availableSpaces.clamp(0, totalSpaces).toInt();

      final percentage = validAvailable / totalSpaces * 100;

      results.add(
        SmartParkingResult(
          parking: parking,
          distanceMeters: distance,
          availabilityPercentage: percentage,
          availableSpaces: validAvailable,
          totalSpaces: totalSpaces,
          isRecommended: false,
        ),
      );
    }

    results.sort((a, b) {
      if (position == null) {
        return a.parking.name.compareTo(b.parking.name);
      }
      final availabilityComparison = b.availabilityPercentage.compareTo(
        a.availabilityPercentage,
      );

      if (availabilityComparison != 0) {
        return availabilityComparison;
      }

      final distanceComparison = a.distanceMeters!.compareTo(b.distanceMeters!);

      if (distanceComparison != 0) {
        return distanceComparison;
      }

      return a.parking.id.compareTo(b.parking.id);
    });

    return SmartParkingResults(
      locationNotice: locationNotice,
      items: [
        for (var i = 0; i < results.length; i++)
          SmartParkingResult(
            parking: results[i].parking,
            distanceMeters: results[i].distanceMeters,
            availabilityPercentage: results[i].availabilityPercentage,
            availableSpaces: results[i].availableSpaces,
            totalSpaces: results[i].totalSpaces,
            isRecommended:
                position != null && i == 0 && results[i].availableSpaces > 0,
          ),
      ],
    );
  }
}
