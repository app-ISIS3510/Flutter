import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DistanceManager {
  static const _nearbyTimeout = Duration(seconds: 8);
  static const _lastKnownMaxAge = Duration(minutes: 5);

  Future<Position> getCurrentPosition({bool useDeviceGps = false}) async {
    await _checkLocationAccess();
    return _getPosition(useDeviceGps, const Duration(seconds: 20));
  }

  Future<({Position position, bool isLastKnown})> getNearbyPosition({
    required bool useDeviceGps,
    bool refreshLocation = false,
  }) async {
    await _checkLocationAccess();
    final cached = await _recentPosition(
      forceAndroidLocationManager: useDeviceGps,
    );
    if (cached != null && useDeviceGps && !refreshLocation) {
      return (position: cached, isLastKnown: true);
    }
    try {
      final position = await _getPosition(useDeviceGps, _nearbyTimeout);
      return (position: position, isLastKnown: false);
    } catch (_) {
      if (cached == null) rethrow;
      return (position: cached, isLastKnown: true);
    }
  }

  Future<Position?> _recentPosition({
    required bool forceAndroidLocationManager,
  }) async {
    if (kIsWeb) return null;
    final useDeviceGps =
        forceAndroidLocationManager &&
        defaultTargetPlatform == TargetPlatform.android;
    final position = await _readLastKnownPosition(useDeviceGps);
    if (position != null || !useDeviceGps) return position;
    return _readLastKnownPosition(false);
  }

  Future<Position?> _readLastKnownPosition(bool useDeviceGps) async {
    try {
      final position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: useDeviceGps,
      ).timeout(const Duration(seconds: 1), onTimeout: () => null);
      if (position == null) return null;
      final age = DateTime.now().difference(position.timestamp);
      if (age.isNegative || age > _lastKnownMaxAge) return null;
      return position;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkLocationAccess() async {
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
  }

  Future<Position> _getPosition(bool useDeviceGps, Duration timeLimit) {
    return Geolocator.getCurrentPosition(
      locationSettings:
          useDeviceGps &&
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              forceLocationManager: true,
              accuracy: LocationAccuracy.high,
              timeLimit: timeLimit,
            )
          : LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: timeLimit,
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
