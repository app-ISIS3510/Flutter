import '../models/parking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../models/parking_option.dart';
import '../models/vehicle.dart';
import '../repositories/parking_repository.dart';
import 'distance_manager.dart';
import 'connectivity_service.dart';

import 'dart:developer' as developer;

import '../state/parking_list_state.dart';
import '../state/parking_detail_state.dart';
import '../state/nearby_parking_state.dart';

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
            ? 'Could not update. Showing saved data, which may be outdated.'
            : 'Could not load parking lots. Please try again.',
      );
    }
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

  void clearParkingDetailsMemory() => repository.clearParkingDetailsMemory();

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
    } catch (_) {
      return const NearbyParkingState(
        errorMessage:
            'Could not load nearby parking lots. No saved parking '
            'data is available. Connect to the Internet and retry.',
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
    final parkingWithLocation = catalog.parkingLots.where((parking) {
      final latitude = parking.latitude;
      final longitude = parking.longitude;
      return latitude != null &&
          longitude != null &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList();

    if (parkingWithLocation.isEmpty) return [];

    final position = await distanceManager.getCurrentPosition(
      useDeviceGps: catalog.isFromCache,
    );
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      throw Exception('Location coordinates are invalid. Please retry.');
    }
    final options = parkingWithLocation.map((parking) {
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
    }).toList();

    options.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return options;
  }
}
