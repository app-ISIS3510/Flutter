import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/parking.dart';
import 'app_database.dart';
import '../../utils/async_operations.dart';

class CachedParkingList {
  final List<Parking> parkingLots;
  final DateTime cachedAt;

  CachedParkingList({required this.parkingLots, required this.cachedAt});
}

class CachedParking {
  final Parking parking;
  final DateTime cachedAt;

  CachedParking({required this.parking, required this.cachedAt});
}

class ParkingLocalDataSource {
  final AppDatabase _database;
  final _BrowserParkingCache? _browser;

  ParkingLocalDataSource({
    AppDatabase? database,
    SharedPreferences? browserPreferences,
  }) : _database = database ?? AppDatabase.instance,
       _browser = kIsWeb || browserPreferences != null
           ? _BrowserParkingCache(browserPreferences)
           : null;

  Future<void> saveParking(Parking parking) async {
    if (_browser != null) return _browser.saveParking(parking);
    final db = await _database.database;
    await db.insert('parking_detail_cache', {
      ...parking.toMap(),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CachedParking?> readParkingById(String id) async {
    if (_browser != null) return _browser.readParkingById(id);
    final db = await _database.database;
    return db.transaction((txn) async {
      final detailRows = await txn.query(
        'parking_detail_cache',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final listRows = await txn.query(
        'parking_cache',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final rows = [...detailRows, ...listRows];
      if (rows.isEmpty) return null;

      // A recent list snapshot can be newer than a previously opened detail.
      rows.sort((a, b) {
        return DateTime.parse(b['cached_at'] as String)
            .compareTo(DateTime.parse(a['cached_at'] as String));
      });

      return CachedParking(
        parking: Parking.fromMap(rows.first),
        cachedAt: DateTime.parse(rows.first['cached_at'] as String),
      );
    });
  }

  Future<void> removeParking(String id) async {
    if (_browser != null) return _browser.removeParking(id);
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final table in ['parking_detail_cache', 'parking_cache']) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<CachedParkingList?> readParkingForNearby() async {
    if (_browser != null) return _browser.readParkingForNearby();
    final db = await _database.database;
    return db.transaction((txn) async {
      final metadata = await txn.query(
        'cache_metadata',
        where: 'cache_key = ?',
        whereArgs: ['parking_list'],
        limit: 1,
      );
      final listUpdatedAt = metadata.isEmpty
          ? null
          : DateTime.parse(metadata.first['last_updated_at'] as String);
      final listRows = await txn.query('parking_cache');
      final detailRows = await txn.query('parking_detail_cache');
      final rowsById = <String, Map<String, Object?>>{
        for (final row in listRows) row['id'] as String: row,
      };

      for (final row in detailRows) {
        final id = row['id'] as String;
        final detailUpdatedAt = DateTime.parse(row['cached_at'] as String);
        final existing = rowsById[id];
        // Do not restore a detail removed by a newer complete list snapshot.
        if (existing == null &&
            listUpdatedAt != null &&
            !detailUpdatedAt.isAfter(listUpdatedAt)) {
          continue;
        }
        if (existing == null ||
            detailUpdatedAt.isAfter(
              DateTime.parse(existing['cached_at'] as String),
            )) {
          rowsById[id] = row;
        }
      }

      if (rowsById.isEmpty && listUpdatedAt == null) return null;
      final rows = rowsById.values.toList();
      final oldestUpdate = rows.fold<DateTime?>(null, (oldest, row) {
        final updatedAt = DateTime.parse(row['cached_at'] as String);
        return oldest == null || updatedAt.isBefore(oldest)
            ? updatedAt
            : oldest;
      });
      return CachedParkingList(
        parkingLots: rows.map((row) => Parking.fromMap(row)).toList(),
        cachedAt: oldestUpdate ?? listUpdatedAt!,
      );
    });
  }

  Future<void> saveParkingLots(List<Parking> parkingLots) async {
    if (_browser != null) return _browser.saveParkingLots(parkingLots);
    final db = await _database.database;
    final cachedAt = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('parking_cache');

      final batch = txn.batch();

      for (final parking in parkingLots) {
        batch.insert('parking_cache', {
          ...parking.toMap(),
          'cached_at': cachedAt,
        });
      }

      await batch.commit(noResult: true);

      await txn.insert('cache_metadata', {
        'cache_key': 'parking_list',
        'last_updated_at': cachedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<CachedParkingList?> readParkingLots() async {
    if (_browser != null) return _browser.readParkingLots();
    final db = await _database.database;

    return db.transaction((txn) async {
      final metadata = await txn.query(
        'cache_metadata',
        where: 'cache_key = ?',
        whereArgs: ['parking_list'],
        limit: 1,
      );

      if (metadata.isEmpty) {
        return null;
      }

      final rows = await txn.query(
        'parking_cache',
        orderBy: 'name COLLATE NOCASE ASC',
      );

      return CachedParkingList(
        parkingLots: rows.map((row) => Parking.fromMap(row)).toList(),
        cachedAt: DateTime.parse(metadata.first['last_updated_at'] as String),
      );
    });
  }
}

/// Public parking data survives reloads in the browser without a SQLite plugin.
/// One value and one write queue keep catalog/detail updates consistent.
class _BrowserParkingCache {
  static const _key = 'parku.parking_cache.v1';
  static final _operations = AsyncSerialExecutor();
  final SharedPreferences? _preferences;
  _BrowserParkingCache(this._preferences);

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _read() async {
    final json = (await _prefs).getString(_key);
    return json == null ? {} : jsonDecode(json) as Map<String, dynamic>;
  }

  Future<void> _save(Map<String, dynamic> value) async {
    if (!await (await _prefs).setString(_key, jsonEncode(value))) {
      throw StateError('Could not save the parking catalog.');
    }
  }

  Map<String, dynamic> _row(Parking parking) => {
    ...parking.toMap(),
    'cached_at': DateTime.now().toUtc().toIso8601String(),
  };

  List<Map<String, dynamic>> _merged(Map<String, dynamic> saved) {
    final catalog = saved['catalog'] as Map<String, dynamic>?;
    final listUpdatedAt = DateTime.tryParse(
      catalog?['updated_at'] as String? ?? '',
    );
    final rows = <String, Map<String, dynamic>>{
      for (final row in (catalog?['rows'] as List? ?? []))
        (row as Map<String, dynamic>)['id'] as String: row,
    };
    final details = Map<String, dynamic>.from(saved['details'] as Map? ?? {});
    for (final entry in details.entries) {
      final row = entry.value as Map<String, dynamic>;
      final date = DateTime.parse(row['cached_at'] as String);
      final previous = rows[entry.key];
      if (previous == null &&
          listUpdatedAt != null &&
          !date.isAfter(listUpdatedAt)) {
        continue;
      }
      if (previous == null ||
          date.isAfter(DateTime.parse(previous['cached_at'] as String))) {
        rows[entry.key] = row;
      }
    }
    return rows.values.toList()..sort(
      (a, b) => (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase(),
      ),
    );
  }

  Future<void> saveParkingLots(List<Parking> lots) => _operations.run(() async {
    final saved = await _read();
    saved['catalog'] = {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'rows': lots.map(_row).toList(),
    };
    await _save(saved);
  });

  Future<void> saveParking(Parking parking) => _operations.run(() async {
    final saved = await _read();
    final details = Map<String, dynamic>.from(saved['details'] as Map? ?? {});
    details[parking.id] = _row(parking);
    saved['details'] = details;
    await _save(saved);
  });

  Future<CachedParkingList?> readParkingLots() => _operations.run(() async {
    final catalog = (await _read())['catalog'] as Map<String, dynamic>?;
    if (catalog == null) return null;
    final rows = (catalog['rows'] as List).cast<Map<String, dynamic>>();
    return CachedParkingList(
      parkingLots: rows.map(Parking.fromMap).toList(),
      cachedAt: DateTime.parse(catalog['updated_at'] as String),
    );
  });

  Future<CachedParkingList?> readParkingForNearby() =>
      _operations.run(() async {
        final saved = await _read();
        final rows = _merged(saved);
        final catalog = saved['catalog'] as Map<String, dynamic>?;
        if (rows.isEmpty && catalog == null) return null;
        return CachedParkingList(
          parkingLots: rows.map(Parking.fromMap).toList(),
          cachedAt: rows.isEmpty
              ? DateTime.parse(catalog!['updated_at'] as String)
              : rows
                    .map((row) => DateTime.parse(row['cached_at'] as String))
                    .reduce((a, b) => a.isBefore(b) ? a : b),
        );
      });

  Future<CachedParking?> readParkingById(String id) =>
      _operations.run(() async {
        final rows = _merged(await _read()).where((row) => row['id'] == id);
        if (rows.isEmpty) return null;
        return CachedParking(
          parking: Parking.fromMap(rows.first),
          cachedAt: DateTime.parse(rows.first['cached_at'] as String),
        );
      });

  Future<void> removeParking(String id) => _operations.run(() async {
    final saved = await _read();
    (saved['details'] as Map?)?.remove(id);
    ((saved['catalog'] as Map?)?['rows'] as List?)?.removeWhere(
      (row) => row['id'] == id,
    );
    await _save(saved);
  });
}
