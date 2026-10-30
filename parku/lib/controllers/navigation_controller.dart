import '../services/navigation_service.dart';
import '../models/navigation_provider.dart';

class NavigationController {
  final NavigationService service;

  NavigationController(this.service);

  Future<bool?> checkNetworkConnection() {
    return service.checkNetworkConnection();
  }

  bool hasValidCoordinates(double? latitude, double? longitude) {
    return NavigationService.hasValidCoordinates(latitude, longitude);
  }

  Future<void> openNavigation({
    required NavigationProvider provider,
    required double latitude,
    required double longitude,
  }) {
    return service.openNavigation(
      provider: provider,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> openGoogleMaps({
    required double latitude,
    required double longitude,
  }) {
    return service.openGoogleMaps(latitude: latitude, longitude: longitude);
  }

  Future<void> openWaze({required double latitude, required double longitude}) {
    return service.openWaze(latitude: latitude, longitude: longitude);
  }
}
