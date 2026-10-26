import 'package:geolocator/geolocator.dart';

class FakeLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  double latitude = 4.6;
  double longitude = -74.1;
  int positionCalls = 0;
  int permissionRequests = 0;
  Object? failure;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls++;
    settings = locationSettings;
    if (failure != null) throw failure!;
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Map<String, dynamic> parkingData({
  String id = 'parking-1',
  String name = 'City U Parking',
  double? latitude = 4.601,
  double? longitude = -74.1,
  int carSpaces = 20,
  int motorcycleSpaces = 10,
  int availableCarSpaces = 8,
  int availableMotorcycleSpaces = 7,
}) {
  return {
    'id': id,
    'name': name,
    'address': 'Calle 20',
    'latitude': latitude,
    'longitude': longitude,
    'car_spaces': carSpaces,
    'motorcycle_spaces': motorcycleSpaces,
    'available_car_spaces': availableCarSpaces,
    'available_motorcycle_spaces': availableMotorcycleSpaces,
    'price_per_minute': 100,
  };
}
