import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/favorite_local_data_source.dart';
import '../data/local/parking_local_data_source.dart';
import '../models/parking.dart';
import '../services/connectivity_service.dart';
import '../utils/error_messages.dart';
import '../state/favorite_list_state.dart';

class FavoriteRepository {
  final SupabaseClient client;
  final FavoriteLocalDataSource localDataSource;
  final ParkingLocalDataSource parkingDataSource;
  final ConnectivityService connectivityService;
  Future<void>? _syncFuture;

  FavoriteRepository(
    this.client, {
    FavoriteLocalDataSource? localDataSource,
    ParkingLocalDataSource? parkingDataSource,
    ConnectivityService? connectivityService,
  }) : localDataSource = localDataSource ?? FavoriteLocalDataSource(),
       parkingDataSource = parkingDataSource ?? ParkingLocalDataSource(),
       connectivityService = connectivityService ?? ConnectivityService();

  String get _userId =>
      client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to continue.'));

  void _checkUser(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw const AuthException('The signed-in account changed.');
    }
  }

  Future<List<Parking>> getFavorites() async =>
      (await getFavoriteSnapshot()).favorites;

  Future<FavoriteListState> getFavoriteSnapshot() async {
    if (client.auth.currentUser == null) {
      return const FavoriteListState(favorites: []);
    }
    final userId = _userId;
    final requestedAt = DateTime.now().toUtc();
    if (await connectivityService.connectionStatus() == false) {
      final saved = await localDataSource.read(userId);
      _checkUser(userId);
      if (saved != null) return saved;
      throw const OfflineActionException();
    }
    try {
      final response = await client
          .from('favorites')
          .select('parking_lots(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 8));
      _checkUser(userId);
      final favorites = (response as List<dynamic>)
          .where((item) => item['parking_lots'] != null)
          .map(
            (item) =>
                Parking.fromMap(item['parking_lots'] as Map<String, dynamic>),
          )
          .toList();
      // Cache real availability rows, rather than treating a base-table
      // capacity as a current availability estimate.
      if (favorites.isNotEmpty) {
        try {
          final details = await client
              .from('parking_lots_with_availability')
              .select()
              .inFilter('id', favorites.map((parking) => parking.id).toList())
              .timeout(const Duration(seconds: 8));
          _checkUser(userId);
          final byId = <String, Parking>{};
          for (final row in details) {
            final parking = Parking.fromMap(row);
            byId[parking.id] = parking;
            try {
              await parkingDataSource.saveParking(parking);
            } catch (_) {}
          }
          for (var i = 0; i < favorites.length; i++) {
            favorites[i] = byId[favorites[i].id] ?? favorites[i];
          }
        } catch (_) {
          _checkUser(userId);
        }
      }
      try {
        await localDataSource.saveSnapshot(
          userId,
          favorites,
          requestedAt: requestedAt,
        );
        final merged = await localDataSource.read(userId);
        _checkUser(userId);
        if (merged != null) {
          return FavoriteListState(
            favorites: merged.favorites,
            updatedAt: merged.updatedAt,
            pendingCount: merged.pendingCount,
          );
        }
      } catch (error, stackTrace) {
        _checkUser(userId);
        developer.log(
          'Could not cache favorites',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return FavoriteListState(
        favorites: favorites,
        updatedAt: DateTime.now().toUtc(),
      );
    } catch (error, stackTrace) {
      _checkUser(userId);
      developer.log(
        'Could not refresh favorites',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        final saved = await localDataSource.read(userId);
        _checkUser(userId);
        if (saved != null) return saved;
      } catch (_) {
        _checkUser(userId);
      }
      rethrow;
    }
  }

  Future<bool?> _savedStatus(
    String userId,
    String parkingId, {
    bool pendingOnly = false,
  }) async {
    try {
      return await localDataSource.status(
        userId,
        parkingId,
        pendingOnly: pendingOnly,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> isFavorite(String parkingId) async {
    if (client.auth.currentUser == null) return false;
    final userId = _userId;
    final pending = await _savedStatus(userId, parkingId, pendingOnly: true);
    _checkUser(userId);
    if (pending != null) return pending;
    final saved = await _savedStatus(userId, parkingId);
    _checkUser(userId);
    if (await connectivityService.connectionStatus() == false) {
      _checkUser(userId);
      if (saved != null) return saved;
      throw const OfflineActionException();
    }
    final requestedAt = DateTime.now().toUtc();
    try {
      final response = await client
          .from('favorites')
          .select('id')
          .eq('parking_id', parkingId)
          .eq('user_id', userId)
          .limit(1)
          .timeout(const Duration(seconds: 8));
      _checkUser(userId);
      final value = response.isNotEmpty;
      try {
        final parking = await parkingDataSource.readParkingById(parkingId);
        await localDataSource.saveStatus(
          userId,
          parkingId,
          value,
          parking?.parking,
          requestedAt: requestedAt,
        );
        final latest = await localDataSource.status(userId, parkingId);
        _checkUser(userId);
        return latest ?? value;
      } catch (_) {
        _checkUser(userId);
        return value;
      }
    } catch (_) {
      _checkUser(userId);
      final saved = await _savedStatus(userId, parkingId);
      _checkUser(userId);
      if (saved != null) return saved;
      rethrow;
    }
  }

  Future<void> _setDesired(String parkingId, bool value) async {
    final userId = _userId;
    Parking? parking;
    if (value) {
      parking = (await parkingDataSource.readParkingById(parkingId))?.parking;
      if (parking == null) {
        await connectivityService.requireConnection();
        final row = await client
            .from('parking_lots_with_availability')
            .select()
            .eq('id', parkingId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        if (row != null) parking = Parking.fromMap(row);
      }
    }
    _checkUser(userId);
    await localDataSource.setDesired(userId, parkingId, value, parking);
    _checkUser(userId);
    unawaited(
      syncPending().catchError((Object error, StackTrace stackTrace) {
        developer.log(
          'Favorite change saved for synchronization',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<void> addFavorite(String parkingId) => _setDesired(parkingId, true);
  Future<void> removeFavorite(String parkingId) =>
      _setDesired(parkingId, false);
  Future<bool> toggleFavorite(String parkingId) async {
    final userId = _userId;
    final saved = await _savedStatus(userId, parkingId);
    _checkUser(userId);
    final current = saved ?? await isFavorite(parkingId);
    _checkUser(userId);
    await _setDesired(parkingId, !current);
    return !current;
  }

  Future<void> syncPending() =>
      _syncFuture ??= _sync().whenComplete(() => _syncFuture = null);

  Future<void> _sync() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    while (client.auth.currentUser?.id == userId) {
      final actions = await localDataSource.due(userId);
      if (actions.isEmpty) return;
      for (final action in actions) {
        if (client.auth.currentUser?.id != userId) return;
        try {
          final parkingId = action['parking_id'] as String;
          if (action['desired_state'] == 1) {
            await client
                .from('favorites')
                .upsert(
                  {'user_id': userId, 'parking_id': parkingId},
                  onConflict: 'user_id,parking_id',
                  ignoreDuplicates: true,
                )
                .timeout(const Duration(seconds: 8));
          } else {
            await client
                .from('favorites')
                .delete()
                .eq('user_id', userId)
                .eq('parking_id', parkingId)
                .timeout(const Duration(seconds: 8));
          }
          await localDataSource.acknowledge(
            action['action_id'] as String,
            userId,
          );
        } catch (error, stackTrace) {
          await localDataSource.postpone(
            action['action_id'] as String,
            action['attempt_count'] as int,
          );
          developer.log(
            'Favorite action remains pending',
            error: error,
            stackTrace: stackTrace,
          );
          return;
        }
      }
    }
  }
}
