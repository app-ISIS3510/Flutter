import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart';

import '../models/most_used_parking.dart';
import '../models/parking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../models/parking_option.dart';
import '../models/smart_parking_result.dart';
import '../models/vehicle.dart';
import '../repositories/parking_repository.dart';
import '../state/nearby_parking_state.dart';
import '../state/parking_detail_state.dart';
import '../state/parking_list_state.dart';
import 'connectivity_service.dart';
import 'distance_manager.dart';
import 'smart_parking_processor.dart';

enum SmartVehicleType { car, motorcycle }

class ParkingService {
  final ParkingRepository repository;
  final DistanceManager distanceManager;
  final ConnectivityService connectivityService;

  ParkingService(
    this.repository,
    this.distanceManager, {
    ConnectivityService? connectivityService,
  }) : connectivityService = connectivityService ?? ConnectivityService();

  Stream<ParkingListState> watchParkingLots() async* {
    yield const ParkingListState(isRefreshing: true);

    List<Parking>? cachedLots;
    DateTime? cachedAt;

    try {
      final cached = await repository.getCachedParkingLots();

      if (cached != null) {
        cachedLots = cached.parkingLots;
        cachedAt = cached.cachedAt;

        yield ParkingListState(
          parkingLots: cachedLots,
          updatedAt: cachedAt,
          isFromCache: true,
          isRefreshing: true,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not read parking cache',
        name: 'ParkingService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (await connectivityService.connectionStatus() == false) {
      yield ParkingListState(
        parkingLots: cachedLots,
        updatedAt: cachedAt,
        isFromCache: cachedLots != null,
        errorMessage: cachedLots == null
            ? 'Connect once to load parking lots.'
            : null,
      );
      return;
    }

    try {
      final parkingLots = await repository.getParkingLots();

      yield ParkingListState(
        parkingLots: parkingLots,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not refresh parking lots',
        name: 'ParkingService',
        error: error,
        stackTrace: stackTrace,
      );

      yield ParkingListState(
        parkingLots: cachedLots,
        updatedAt: cachedAt,
        isFromCache: cachedLots != null,
        errorMessage: cachedLots != null
            ? 'Could not refresh parking lots.'
            : 'Could not load parking lots. Please try again.',
      );
    }
  }

  Future<List<MostUsedParking>> getMostUsedParkingLots() {
    return repository.getMostUsedParkingLots().timeout(
      const Duration(seconds: 8),
    );
  }

  Future<List<Parking>> getParkingLots() {
    return repository.getParkingLots();
  }

  Future<ParkingCatalogSnapshot> getParkingCatalog() {
    return repository.getParkingCatalog();
  }

  Future<ParkingCatalogSnapshot?> getCachedParkingCatalog() {
    return repository.getCachedParkingCatalog();
  }

  Future<Parking?> getParkingById(String id) {
    return repository.getParkingById(id);
  }

  Future<ParkingDetailState> getParkingDetails(String id) {
    return repository.getParkingDetails(id);
  }

  ParkingDetailState? readMemoryParkingDetails(String id) {
    return repository.readMemoryParkingDetails(id);
  }

  void clearParkingDetailsMemory() {
    repository.clearParkingDetailsMemory();
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return repository.searchParkingLots(query);
  }

  Future<List<Parking>> getNearestParkingLots({int limit = 4}) async {
    final options = await getParkingOptions();

    return options.take(limit).map((option) => option.parking).toList();
  }

  Future<List<ParkingOption>> getParkingOptions({
    VehicleType? vehicleType,
  }) async {
    final catalog = await repository.getParkingCatalog();

    return _calculateParkingOptions(catalog, vehicleType: vehicleType);
  }

  Future<NearbyParkingState> getNearbyParking({
    VehicleType? vehicleType,
  }) async {
    final ParkingCatalogSnapshot catalog;

    try {
      catalog = await repository.getParkingCatalog();
    } catch (error, stackTrace) {
      developer.log(
        'Could not load nearby parking catalog',
        name: 'ParkingService',
        error: error,
        stackTrace: stackTrace,
      );

      return const NearbyParkingState(
        errorMessage:
            'Could not load nearby parking lots. Connect and try again later.',
      );
    }

    final options = await _calculateParkingOptions(
      catalog,
      vehicleType: vehicleType,
    );

    return NearbyParkingState(
      options: options,
      updatedAt: catalog.updatedAt,
      isFromCache: catalog.isFromCache,
    );
  }

  Future<List<ParkingOption>> _calculateParkingOptions(
    ParkingCatalogSnapshot catalog, {
    VehicleType? vehicleType,
  }) async {
    final parkingWithLocation = catalog.parkingLots
        .where(_hasValidCoordinates)
        .toList();

    if (parkingWithLocation.isEmpty) return [];

    final position = await distanceManager.getCurrentPosition(
      useDeviceGps: catalog.isFromCache,
    );

    if (!_validCoordinates(position.latitude, position.longitude)) {
      throw StateError('Location coordinates are invalid.');
    }

    final options = parkingWithLocation
        .map((parking) {
          return ParkingOption(
            parking: parking,
            distanceMeters: distanceManager.calculateDistance(
              userLatitude: position.latitude,
              userLongitude: position.longitude,
              parkingLatitude: parking.latitude!,
              parkingLongitude: parking.longitude!,
            ),
            vehicleType: vehicleType,
            isFromCache: catalog.isFromCache,
            updatedAt: catalog.updatedAt,
          );
        })
        .where((option) => option.distanceMeters.isFinite)
        .toList();

    options.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return options;
  }

  bool _validCoordinates(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  bool _hasValidCoordinates(Parking parking) {
    final latitude = parking.latitude;
    final longitude = parking.longitude;

    return latitude != null &&
        longitude != null &&
        _validCoordinates(latitude, longitude);
  }

  Future<SmartParkingResults> getSmartParkingResults({
    required int radiusMeters,
    required SmartVehicleType vehicleType,
  }) async {
    if (radiusMeters <= 0) {
      throw ArgumentError('Radius must be greater than zero.');
    }

    final catalog = await repository.getParkingCatalog();
    final parkingLots = catalog.parkingLots;

    if (parkingLots.isEmpty) {
      return const SmartParkingResults(items: []);
    }

    Position? position;
    String? locationNotice;

    try {
      final currentPosition = await distanceManager.getCurrentPosition(
        useDeviceGps: catalog.isFromCache,
      );

      if (!_validCoordinates(
        currentPosition.latitude,
        currentPosition.longitude,
      )) {
        throw StateError('Location coordinates are invalid.');
      }

      position = currentPosition;
    } catch (error) {
      var reason = 'Could not get your location.';
      final message = error.toString();

      if (message.contains('permission')) {
        reason = 'Location permission is not enabled.';
      } else if (message.contains('disabled')) {
        reason = 'Location services are turned off.';
      }

      locationNotice =
          '$reason Showing parking lots without distances or a '
          'radius filter. Enable location and tap Refresh location to search nearby.';
    }

    final processed = await processSmartParkingInIsolate(
      SmartParkingProcessingInput(
        parkingLots: [for (final parking in parkingLots) parking.toMap()],
        radiusMeters: radiusMeters,
        isCar: vehicleType == SmartVehicleType.car,
        latitude: position?.latitude,
        longitude: position?.longitude,
      ),
    );

    return SmartParkingResults(
      locationNotice: locationNotice,
      items: [
        for (final item in processed)
          SmartParkingResult(
            parking: Parking.fromMap(item['parking'] as Map<String, dynamic>),
            distanceMeters: item['distance'] as double?,
            availabilityPercentage: item['percentage'] as double,
            availableSpaces: item['available'] as int,
            totalSpaces: item['total'] as int,
            isRecommended: item['recommended'] as bool,
          ),
      ],
    );
  }
}
