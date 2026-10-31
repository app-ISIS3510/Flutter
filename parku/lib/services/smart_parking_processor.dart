import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

List<Map<String, dynamic>> processSmartParking(
  SmartParkingProcessingInput input,
) {
  final hasLocation = input.latitude != null && input.longitude != null;

  final results = <Map<String, dynamic>>[];

  for (final parking in input.parkingLots) {
    final latitude = (parking['latitude'] as num?)?.toDouble();
    final longitude = (parking['longitude'] as num?)?.toDouble();

    if (hasLocation) {
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
    }

    final totalSpaces = input.isCar
        ? parking['car_spaces'] as int
        : parking['motorcycle_spaces'] as int;

    final availableSpaces = input.isCar
        ? parking['available_car_spaces'] as int
        : parking['available_motorcycle_spaces'] as int;

    if (totalSpaces <= 0) continue;

    double? distance;

    if (hasLocation) {
      distance = Geolocator.distanceBetween(
        input.latitude!,
        input.longitude!,
        latitude!,
        longitude!,
      );

      if (!distance.isFinite || distance > input.radiusMeters) {
        continue;
      }
    }

    final validAvailable = availableSpaces.clamp(0, totalSpaces).toInt();
    final percentage = validAvailable / totalSpaces * 100;

    results.add({
      'parking': parking,
      'distance': distance,
      'percentage': percentage,
      'available': validAvailable,
      'total': totalSpaces,
    });
  }

  results.sort((a, b) {
    final firstParking = a['parking'] as Map<String, dynamic>;
    final secondParking = b['parking'] as Map<String, dynamic>;

    if (!hasLocation) {
      return (firstParking['name'] as String).compareTo(
        secondParking['name'] as String,
      );
    }

    final availabilityComparison = (b['percentage'] as double).compareTo(
      a['percentage'] as double,
    );

    if (availabilityComparison != 0) {
      return availabilityComparison;
    }

    final distanceComparison = (a['distance'] as double).compareTo(
      b['distance'] as double,
    );

    if (distanceComparison != 0) {
      return distanceComparison;
    }

    return (firstParking['id'] as String).compareTo(
      secondParking['id'] as String,
    );
  });

  for (var i = 0; i < results.length; i++) {
    results[i]['recommended'] =
        hasLocation && i == 0 && (results[i]['available'] as int) > 0;
  }

  return results;
}

Future<List<Map<String, dynamic>>> processSmartParkingInIsolate(
  SmartParkingProcessingInput input,
) async {
  if (input.parkingLots.length < 100) {
    return processSmartParking(input);
  }

  return compute(processSmartParking, input);
}
