import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DistanceManager {
  Future<Position> getCurrentPosition({bool useDeviceGps = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission was permanently denied.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          useDeviceGps &&
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              forceLocationManager: true,
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 20),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 20),
            ),
    );
  }

  double calculateDistance({
    required double userLatitude,
    required double userLongitude,
    required double parkingLatitude,
    required double parkingLongitude,
  }) {
    return Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      parkingLatitude,
      parkingLongitude,
    );
  }
}
