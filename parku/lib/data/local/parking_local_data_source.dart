import 'package:sqflite/sqflite.dart';

import '../../models/parking.dart';
import 'app_database.dart';

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

  ParkingLocalDataSource({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  Future<void> saveParking(Parking parking) async {
    final db = await _database.database;
    await db.insert('parking_detail_cache', {
      ...parking.toMap(),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<CachedParking?> readParkingById(String id) async {
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
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final table in ['parking_detail_cache', 'parking_cache']) {
        await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<CachedParkingList?> readParkingForNearby() async {
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
