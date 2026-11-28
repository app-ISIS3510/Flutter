import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart';

import '../models/most_used_parking.dart';
import '../models/most_used_parking_ranking.dart';
import '../models/parking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../models/parking_option.dart';
import '../models/smart_parking_result.dart';
import '../models/vehicle.dart';
import '../repositories/parking_repository.dart';
import '../repositories/user_local_store.dart';
import '../state/nearby_parking_state.dart';
import '../state/parking_detail_state.dart';
import '../state/parking_list_state.dart';
import '../utils/async_operations.dart';
import '../utils/error_messages.dart';
import 'connection_failure.dart';
import 'connectivity_service.dart';
import 'distance_manager.dart';
import 'smart_parking_processor.dart';
import '../models/parking_search_result.dart';

enum SmartVehicleType { car, motorcycle }

class ParkingService {
  final ParkingRepository repository;
  final DistanceManager distanceManager;
  final ConnectivityService connectivityService;
  final UserLocalStore store;
  final _rankingReads = SingleFlight<String, MostUsedParkingRanking>();

  ParkingService(
    this.repository,
    this.distanceManager, {
    ConnectivityService? connectivityService,
    UserLocalStore? store,
  }) : connectivityService = connectivityService ?? ConnectivityService(),
       store = store ?? UserLocalStore(repository.client);

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

  Future<MostUsedParkingRanking> getMostUsedParkingRanking() async {
    final owner = store.userId;
    return _rankingReads.run(owner, () => _loadMostUsedParkingRanking(owner));
  }

  Future<MostUsedParkingRanking> _loadMostUsedParkingRanking(
    String owner,
  ) async {
    try {
      await connectivityService.requireConnection();
      store.checkUser(owner);
      final parkingLots = await getMostUsedParkingLots();
      store.checkUser(owner);
      final ranking = MostUsedParkingRanking(
        parkingLots: parkingLots,
        updatedAt: DateTime.now().toUtc(),
      );
      try {
        await store.write('most_used_parking_ranking', ranking.toMap());
      } catch (error, stackTrace) {
        store.checkUser(owner);
        developer.log(
          'Could not save parking ranking',
          name: 'ParkingService',
          error: error,
          stackTrace: stackTrace,
        );
      }
      store.checkUser(owner);
      return ranking;
    } catch (error) {
      store.checkUser(owner);
      if (error is! OfflineActionException && !isConnectionError(error)) {
        rethrow;
      }
      final saved = await store.read('most_used_parking_ranking');
      store.checkUser(owner);
      if (saved == null) rethrow;
      return MostUsedParkingRanking.fromMap(saved);
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

  void clearParkingDetailsMemory() {
    repository.clearParkingDetailsMemory();
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return repository.searchParkingLots(query);
  }

  Future<ParkingSearchResult> searchParkingLotsWithSource(String query) {
    return repository.searchParkingLotsWithSource(query);
  }

  Future<List<Parking>> getNearestParkingLots({int limit = 4}) async {
    final options = await getParkingOptions();

    return options.take(limit).map((option) => option.parking).toList();
  }

  Future<List<ParkingOption>> getParkingOptions({
    VehicleType? vehicleType,
  }) async {
    final catalog = await repository.getParkingCatalog();
    if (!catalog.parkingLots.any(_hasValidCoordinates)) return [];
    final position = await distanceManager.getCurrentPosition(
      useDeviceGps: catalog.isFromCache,
    );
    return _calculateParkingOptions(
      catalog,
      position,
      vehicleType: vehicleType,
    );
  }

  Stream<NearbyParkingState> watchNearbyParking({
    VehicleType? vehicleType,
    bool refreshLocation = false,
  }) async* {
    final connection = connectivityService.connectionStatus();
    ParkingCatalogSnapshot? cached;
    try {
      cached = await repository.getCachedParkingCatalog();
    } catch (error, stackTrace) {
      developer.log(
        'Could not read the saved nearby parking catalog',
        name: 'ParkingService',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (cached != null && cached.parkingLots.isNotEmpty) {
      yield _nearbyState(cached, vehicleType: vehicleType, isLocating: true);
    }

    final offline = await connection == false;
    var catalog = cached;
    if (!offline) {
      try {
        catalog = await repository.getParkingCatalog();
      } catch (error, stackTrace) {
        developer.log(
          'Could not refresh the nearby parking catalog',
          name: 'ParkingService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    if (catalog == null) {
      yield NearbyParkingState(
        errorMessage: offline
            ? 'No saved parking lots are available. Connect once to load them.'
            : 'Could not load nearby parking lots. Connect and try again later.',
      );
      return;
    }

    if (!catalog.parkingLots.any(_hasValidCoordinates)) {
      yield _nearbyState(
        catalog,
        vehicleType: vehicleType,
        locationNotice: catalog.parkingLots.isEmpty ? null : 'Showing parking lots without distances. These lots have no saved coordinates.',
      );
      return;
    }
    if (catalog != cached) {
      yield _nearbyState(catalog, vehicleType: vehicleType, isLocating: true);
    }

    try {
      final result = await distanceManager.getNearbyPosition(
        useDeviceGps: offline || catalog.isFromCache,
        refreshLocation: refreshLocation,
      );
      yield _nearbyState(
        catalog,
        vehicleType: vehicleType,
        position: result.position,
        locationNotice: result.isLastKnown
            ? 'Distances use your last known location.'
            : null,
      );
    } catch (error) {
      final reason = switch (error.toString()) {
        'Exception: Location services are disabled.' =>
          'Device location is turned off.',
        'Exception: Location permission was denied.' ||
        'Exception: Location permission was permanently denied.' =>
          'ParkU needs location permission to show distances.',
        _ => 'Could not get your location.',
      };
      yield _nearbyState(
        catalog,
        vehicleType: vehicleType,
        locationNotice: '$reason Showing parking lots without distances.',
      );
    }
  }

  NearbyParkingState _nearbyState(
    ParkingCatalogSnapshot catalog, {
    VehicleType? vehicleType,
    Position? position,
    bool isLocating = false,
    String? locationNotice,
  }) => NearbyParkingState(
    options: _calculateParkingOptions(
      catalog,
      position,
      vehicleType: vehicleType,
    ),
    updatedAt: catalog.updatedAt,
    isFromCache: catalog.isFromCache,
    isLocating: isLocating,
    locationNotice: locationNotice,
  );

  List<ParkingOption> _calculateParkingOptions(
    ParkingCatalogSnapshot catalog,
    Position? position, {
    VehicleType? vehicleType,
  }) {
    if (position != null &&
        !_validCoordinates(position.latitude, position.longitude)) {
      throw StateError('Location coordinates are invalid.');
    }

    final lots = position == null
        ? catalog.parkingLots
        : catalog.parkingLots.where(_hasValidCoordinates);
    final options = [
      for (final parking in lots)
        ParkingOption(
          parking: parking,
          distanceMeters: position == null
              ? null
              : distanceManager.calculateDistance(
                  userLatitude: position.latitude,
                  userLongitude: position.longitude,
                  parkingLatitude: parking.latitude!,
                  parkingLongitude: parking.longitude!,
                ),
          vehicleType: vehicleType,
          isFromCache: catalog.isFromCache,
          updatedAt: catalog.updatedAt,
        ),
    ];
    if (position != null) {
      options.removeWhere((option) => !option.distanceMeters!.isFinite);
      options.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
    }
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
    CancellationToken? cancellationToken,
  }) async {
    if (radiusMeters <= 0) {
      throw ArgumentError('Radius must be greater than zero.');
    }

    cancellationToken?.throwIfCancelled();

    final catalog = await repository.getParkingCatalog();

    cancellationToken?.throwIfCancelled();

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

    cancellationToken?.throwIfCancelled();

    final processed = await processParkingCatalog(
      parkingLots: parkingLots,
      radiusMeters: radiusMeters,
      isCar: vehicleType == SmartVehicleType.car,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    cancellationToken?.throwIfCancelled();

    return SmartParkingResults(
      locationNotice: locationNotice,
      updatedAt: catalog.updatedAt,
      isFromCache: catalog.isFromCache,
      items: processed,
    );
  }
}
