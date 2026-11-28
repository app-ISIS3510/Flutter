import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/parking.dart';
import '../models/smart_parking_result.dart';

const smartParkingIsolateThreshold = 100;

class SmartParkingProcessingInput {
  final List<Map<String, dynamic>> parkingLots;
  final int radiusMeters;
  final bool isCar;
  final double? latitude;
  final double? longitude;

  const SmartParkingProcessingInput({
    required this.parkingLots,
    required this.radiusMeters,
    required this.isCar,
    required this.latitude,
    required this.longitude,
  });
}

class _RankedParking<T> {
  final T parking;
  final String id;
  final String name;
  final double? distance;
  final double percentage;
  final int available;
  final int total;

  const _RankedParking({
    required this.parking,
    required this.id,
    required this.name,
    required this.distance,
    required this.percentage,
    required this.available,
    required this.total,
  });
}

List<_RankedParking<T>> _rankParking<T>({
  required List<T> parkingLots,
  required int radiusMeters,
  required double? latitude,
  required double? longitude,
  required String Function(T) getId,
  required String Function(T) getName,
  required double? Function(T) getLatitude,
  required double? Function(T) getLongitude,
  required int Function(T) getTotal,
  required int Function(T) getAvailable,
}) {
  final hasLocation = latitude != null && longitude != null;
  final results = <_RankedParking<T>>[];

  for (final parking in parkingLots) {
    final parkingLatitude = getLatitude(parking);
    final parkingLongitude = getLongitude(parking);

    if (hasLocation) {
      if (parkingLatitude == null ||
          parkingLongitude == null ||
          !parkingLatitude.isFinite ||
          !parkingLongitude.isFinite ||
          parkingLatitude < -90 ||
          parkingLatitude > 90 ||
          parkingLongitude < -180 ||
          parkingLongitude > 180) {
        continue;
      }
    }

    final total = getTotal(parking);

    if (total <= 0) continue;

    double? distance;

    if (hasLocation) {
      distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        parkingLatitude!,
        parkingLongitude!,
      );

      if (!distance.isFinite || distance > radiusMeters) {
        continue;
      }
    }

    final available = getAvailable(parking).clamp(0, total).toInt();

    results.add(
      _RankedParking<T>(
        parking: parking,
        id: getId(parking),
        name: getName(parking),
        distance: distance,
        percentage: available / total * 100,
        available: available,
        total: total,
      ),
    );
  }

  results.sort((a, b) {
    if (!hasLocation) {
      return a.name.compareTo(b.name);
    }

    final availabilityComparison = b.percentage.compareTo(a.percentage);

    if (availabilityComparison != 0) {
      return availabilityComparison;
    }

    final distanceComparison = a.distance!.compareTo(b.distance!);

    if (distanceComparison != 0) {
      return distanceComparison;
    }

    return a.id.compareTo(b.id);
  });

  return results;
}

List<Map<String, dynamic>> processSmartParking(
  SmartParkingProcessingInput input,
) {
  final hasLocation = input.latitude != null && input.longitude != null;

  final ranked = _rankParking<Map<String, dynamic>>(
    parkingLots: input.parkingLots,
    radiusMeters: input.radiusMeters,
    latitude: input.latitude,
    longitude: input.longitude,
    getId: (parking) => parking['id'] as String,
    getName: (parking) => parking['name'] as String,
    getLatitude: (parking) => (parking['latitude'] as num?)?.toDouble(),
    getLongitude: (parking) => (parking['longitude'] as num?)?.toDouble(),
    getTotal: (parking) => input.isCar
        ? parking['car_spaces'] as int
        : parking['motorcycle_spaces'] as int,
    getAvailable: (parking) => input.isCar
        ? parking['available_car_spaces'] as int
        : parking['available_motorcycle_spaces'] as int,
  );

  return [
    for (var i = 0; i < ranked.length; i++)
      {
        'parking': ranked[i].parking,
        'distance': ranked[i].distance,
        'percentage': ranked[i].percentage,
        'available': ranked[i].available,
        'total': ranked[i].total,
        'recommended': hasLocation && i == 0 && ranked[i].available > 0,
      },
  ];
}

Future<List<Map<String, dynamic>>> processSmartParkingInIsolate(
  SmartParkingProcessingInput input,
) async {
  if (input.parkingLots.length < smartParkingIsolateThreshold) {
    return processSmartParking(input);
  }

  return compute(processSmartParking, input);
}

Future<List<SmartParkingResult>> processParkingCatalog({
  required List<Parking> parkingLots,
  required int radiusMeters,
  required bool isCar,
  required double? latitude,
  required double? longitude,
}) async {
  final hasLocation = latitude != null && longitude != null;

  if (parkingLots.length < smartParkingIsolateThreshold) {
    final ranked = _rankParking<Parking>(
      parkingLots: parkingLots,
      radiusMeters: radiusMeters,
      latitude: latitude,
      longitude: longitude,
      getId: (parking) => parking.id,
      getName: (parking) => parking.name,
      getLatitude: (parking) => parking.latitude,
      getLongitude: (parking) => parking.longitude,
      getTotal: (parking) =>
          isCar ? parking.carSpaces : parking.motorcycleSpaces,
      getAvailable: (parking) => isCar
          ? parking.availableCarSpaces
          : parking.availableMotorcycleSpaces,
    );

    return [
      for (var i = 0; i < ranked.length; i++)
        SmartParkingResult(
          parking: ranked[i].parking,
          distanceMeters: ranked[i].distance,
          availabilityPercentage: ranked[i].percentage,
          availableSpaces: ranked[i].available,
          totalSpaces: ranked[i].total,
          isRecommended: hasLocation && i == 0 && ranked[i].available > 0,
        ),
    ];
  }

  final processed = await processSmartParkingInIsolate(
    SmartParkingProcessingInput(
      parkingLots: [for (final parking in parkingLots) parking.toMap()],
      radiusMeters: radiusMeters,
      isCar: isCar,
      latitude: latitude,
      longitude: longitude,
    ),
  );

  return [
    for (final item in processed)
      SmartParkingResult(
        parking: Parking.fromMap(item['parking'] as Map<String, dynamic>),
        distanceMeters: item['distance'] as double?,
        availabilityPercentage: item['percentage'] as double,
        availableSpaces: item['available'] as int,
        totalSpaces: item['total'] as int,
        isRecommended: item['recommended'] as bool,
      ),
  ];
}
