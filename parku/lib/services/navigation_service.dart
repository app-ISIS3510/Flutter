import '../adapters/google_maps_adapter.dart';
import '../adapters/navigation_adapter.dart';
import '../adapters/waze_adapter.dart';

class NavigationService {
  final NavigationAdapter googleMapsAdapter;
  final NavigationAdapter wazeAdapter;

  NavigationService({
    required this.googleMapsAdapter,
    required this.wazeAdapter,
  });

  factory NavigationService.create() {
    return NavigationService(
      googleMapsAdapter: GoogleMapsAdapter(),
      wazeAdapter: WazeAdapter(),
    );
  }

  Future<void> openGoogleMaps({
    required double latitude,
    required double longitude,
  }) {
    return googleMapsAdapter.openNavigation(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> openWaze({
    required double latitude,
    required double longitude,
  }) {
    return wazeAdapter.openNavigation(
      latitude: latitude,
      longitude: longitude,
    );
  }
}