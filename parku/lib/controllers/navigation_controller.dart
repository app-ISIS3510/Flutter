import '../services/navigation_service.dart';

class NavigationController {
  final NavigationService service;

  NavigationController(this.service);

  Future<void> openGoogleMaps({
    required double latitude,
    required double longitude,
  }) {
    return service.openGoogleMaps(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> openWaze({
    required double latitude,
    required double longitude,
  }) {
    return service.openWaze(
      latitude: latitude,
      longitude: longitude,
    );
  }
}