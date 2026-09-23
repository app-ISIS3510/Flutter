import 'package:geolocator/geolocator.dart';

class DistanceManager {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission was permanently denied.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
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