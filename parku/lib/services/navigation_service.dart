import 'dart:developer' as developer;

import '../adapters/google_maps_adapter.dart';
import '../adapters/navigation_adapter.dart';
import '../adapters/waze_adapter.dart';
import '../models/navigation_provider.dart';
import 'connectivity_service.dart';

class NavigationService {
  final NavigationAdapter googleMapsAdapter;
  final NavigationAdapter wazeAdapter;
  final ConnectivityService connectivityService;

  NavigationService({
    required this.googleMapsAdapter,
    required this.wazeAdapter,
    ConnectivityService? connectivityService,
  }) : connectivityService = connectivityService ?? ConnectivityService();

  Future<bool?> checkNetworkConnection() async {
    try {
      return await connectivityService.hasNetworkConnection().timeout(
        const Duration(seconds: 3),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not check connectivity before external navigation',
        name: 'NavigationService',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static bool hasValidCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  Future<void> openNavigation({
    required NavigationProvider provider,
    required double latitude,
    required double longitude,
  }) {
    if (!hasValidCoordinates(latitude, longitude)) {
      throw ArgumentError('Parking location is not available.');
    }
    final adapter = provider == NavigationProvider.googleMaps
        ? googleMapsAdapter
        : wazeAdapter;
    return adapter.openNavigation(latitude: latitude, longitude: longitude);
  }

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
    return openNavigation(
      provider: NavigationProvider.googleMaps,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> openWaze({required double latitude, required double longitude}) {
    return openNavigation(
      provider: NavigationProvider.waze,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
