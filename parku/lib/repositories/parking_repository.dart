import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/parking_local_data_source.dart';
import '../data/memory/lru_cache.dart';

import 'dart:developer' as developer;

import '../models/parking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../state/parking_detail_state.dart';
import '../utils/async_operations.dart';
import '../services/connectivity_service.dart';
import '../models/most_used_parking.dart';

class ParkingRepository {
  final SupabaseClient client;
  final ParkingLocalDataSource localDataSource;
  final LruCache<String, CachedParking> _detailMemoryCache;
  final _listReads = SingleFlight<String, List<Parking>>();
  final _detailReads = SingleFlight<String, Parking?>();
  final _detailStateReads = SingleFlight<String, ParkingDetailState>();
  final ConnectivityService connectivityService;

  ParkingRepository(
    this.client, {
    ParkingLocalDataSource? localDataSource,
    int detailCacheCapacity = 20,
    ConnectivityService? connectivityService,
  }) : localDataSource = localDataSource ?? ParkingLocalDataSource(),
       _detailMemoryCache = LruCache(capacity: detailCacheCapacity),
       connectivityService = connectivityService ?? ConnectivityService();

  Future<List<MostUsedParking>> getMostUsedParkingLots() async {
    final response = await client
        .from('bq2_top_parking_completed_last_7_days')
        .select('parking_id,parking_name,completed_sessions')
        .order('completed_sessions', ascending: false)
        .order('parking_id', ascending: true)
        .limit(3);

    return response
        .map((row) => MostUsedParking.fromMap(row))
        .toList();
  }

  ParkingDetailState? readMemoryParkingDetails(String id) {
    final cached = _detailMemoryCache.get(id);
    if (cached == null) return null;
    return ParkingDetailState(
      parking: cached.parking,
      updatedAt: cached.cachedAt,
      isFromCache: true,
      isFromMemory: true,
    );
  }

  void clearParkingDetailsMemory() => _detailMemoryCache.clear();

  Future<CachedParkingList?> getCachedParkingLots() {
    return localDataSource.readParkingLots();
  }

  Future<ParkingCatalogSnapshot?> getCachedParkingCatalog() async {
    final cached = await localDataSource.readParkingForNearby();
    if (cached == null) return null;
    return ParkingCatalogSnapshot(
      parkingLots: cached.parkingLots,
      updatedAt: cached.cachedAt,
      isFromCache: true,
    );
  }

  Future<List<Parking>> getParkingLots() =>
      _listReads.run('catalog', _fetchParkingLots);

  Future<List<Parking>> _fetchParkingLots() async {
    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .order('name')
        .timeout(const Duration(seconds: 15));

    final parkingLots = (response as List<dynamic>)
        .map((item) => Parking.fromMap(item as Map<String, dynamic>))
        .toList();

    // Refresh only already-viewed details. Loading the catalog must not fill
    // the LRU or change which details the user accessed most recently.
    final byId = {for (final parking in parkingLots) parking.id: parking};
    final observedAt = DateTime.now().toUtc();
    for (final id in _detailMemoryCache.keys) {
      final parking = byId[id];
      if (parking == null) {
        _detailMemoryCache.remove(id);
      } else {
        _detailMemoryCache.updateIfPresent(
          id,
          CachedParking(parking: parking, cachedAt: observedAt),
        );
      }
    }

    try {
      await localDataSource.saveParkingLots(parkingLots);
    } catch (error, stackTrace) {
      developer.log(
        'Could not update parking cache',
        name: 'ParkingRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return parkingLots;
  }

  Future<ParkingCatalogSnapshot> getParkingCatalog() async {
    try {
      final parkingLots = await getParkingLots();
      return ParkingCatalogSnapshot(
        parkingLots: parkingLots,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not refresh the catalog; trying saved parking data',
        name: 'ParkingRepository',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        final cached = await localDataSource.readParkingForNearby();
        if (cached != null) {
          return ParkingCatalogSnapshot(
            parkingLots: cached.parkingLots,
            updatedAt: cached.cachedAt,
            isFromCache: true,
          );
        }
      } catch (cacheError, cacheStackTrace) {
        developer.log(
          'Could not read saved parking data',
          name: 'ParkingRepository',
          error: cacheError,
          stackTrace: cacheStackTrace,
        );
      }
      rethrow;
    }
  }

  Future<Parking?> getParkingById(String id) =>
      _detailReads.run(id, () => _fetchParkingById(id));

  Future<Parking?> _fetchParkingById(String id) async {
    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));

    final parking = response == null ? null : Parking.fromMap(response);

    if (parking == null) {
      _detailMemoryCache.remove(id);
    } else {
      _detailMemoryCache.put(
        id,
        CachedParking(parking: parking, cachedAt: DateTime.now().toUtc()),
      );
    }

    try {
      if (parking == null) {
        await localDataSource.removeParking(id);
      } else {
        await localDataSource.saveParking(parking);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not update parking detail cache',
        name: 'ParkingRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return parking;
  }

  Future<ParkingDetailState> getParkingDetails(String id) =>
      _detailStateReads.run(id, () => _fetchParkingDetails(id));

  Future<ParkingDetailState> _fetchParkingDetails(String id) async {
    try {
      await connectivityService.requireConnection();
      final parking = await getParkingById(id);
      return ParkingDetailState(
        parking: parking,
        updatedAt: parking == null
            ? null
            : _detailMemoryCache.peek(id)?.cachedAt ?? DateTime.now().toUtc(),
        errorMessage: parking == null ? 'Parking lot not found.' : null,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not refresh parking details',
        name: 'ParkingRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final memory = readMemoryParkingDetails(id);
    if (memory != null) {
      return ParkingDetailState(
        parking: memory.parking,
        updatedAt: memory.updatedAt,
        isFromCache: true,
        isFromMemory: true,
        errorMessage: 'Could not refresh parking details.',
      );
    }

    try {
      final cached = await localDataSource.readParkingById(id);
      if (cached != null) {
        _detailMemoryCache.put(id, cached);
        return ParkingDetailState(
          parking: cached.parking,
          updatedAt: cached.cachedAt,
          isFromCache: true,
          errorMessage: 'Could not refresh parking details.',
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Could not read parking detail cache',
        name: 'ParkingRepository',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return const ParkingDetailState(
      errorMessage:
          'Could not load parking details. No saved details are available. '
          'Connect to the Internet and retry.',
    );
  }

  Future<List<Parking>> searchParkingLots(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return Future.value([]);
    return _listReads.run(
      'search:${trimmedQuery.toLowerCase()}',
      () => _searchParkingLots(trimmedQuery),
    );
  }

  Future<List<Parking>> _searchParkingLots(String trimmedQuery) async {
    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .or('name.ilike.%$trimmedQuery%,address.ilike.%$trimmedQuery%')
        .order('name')
        .timeout(const Duration(seconds: 15));

    return (response as List<dynamic>)
        .map((item) => Parking.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
