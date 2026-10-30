import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/parking.dart';
import '../../state/favorite_list_state.dart';
import '../../utils/client_id.dart';
import 'app_database.dart';

class FavoriteLocalDataSource {
  final AppDatabase _database;

  FavoriteLocalDataSource({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  Future<FavoriteListState?> read(String userId) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final metadata = await txn.query(
        'favorite_snapshot_metadata',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final rows = await txn.query(
        'favorite_cache',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
      final pending = await txn.query(
        'pending_favorite_actions',
        columns: ['action_id'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (metadata.isEmpty && rows.isEmpty && pending.isEmpty) return null;
      return FavoriteListState(
        favorites: rows
            .where(
              (row) => row['is_favorite'] == 1 && row['parking_json'] != null,
            )
            .map(
              (row) => Parking.fromMap(
                jsonDecode(row['parking_json'] as String)
                    as Map<String, dynamic>,
              ),
            )
            .toList(),
        isFromCache: true,
        updatedAt: metadata.isEmpty
            ? null
            : DateTime.parse(metadata.first['updated_at'] as String),
        pendingCount: pending.length,
      );
    });
  }

  Future<bool?> status(
    String userId,
    String parkingId, {
    bool pendingOnly = false,
  }) async {
    final db = await _database.database;
    if (pendingOnly) {
      final rows = await db.query(
        'pending_favorite_actions',
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, parkingId],
      );
      return rows.isEmpty ? null : rows.first['desired_state'] == 1;
    }
    return db.transaction((txn) async {
      final rows = await txn.query(
        'favorite_cache',
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, parkingId],
      );
      if (rows.isNotEmpty) return rows.first['is_favorite'] == 1;
      final snapshot = await txn.query(
        'favorite_snapshot_metadata',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return snapshot.isEmpty ? null : false;
    });
  }

  Future<void> saveStatus(
    String userId,
    String parkingId,
    bool value,
    Parking? parking, {
    required DateTime requestedAt,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final pending = await txn.query(
        'pending_favorite_actions',
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, parkingId],
      );
      if (pending.isNotEmpty) return;
      final old = await txn.query(
        'favorite_cache',
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, parkingId],
      );
      if (old.isNotEmpty &&
          DateTime.parse(old.first['updated_at'] as String)
              .isAfter(requestedAt)) {
        return;
      }
      await txn.insert('favorite_cache', {
        'user_id': userId,
        'parking_id': parkingId,
        'is_favorite': value ? 1 : 0,
        'parking_json': parking == null
            ? (old.isEmpty ? null : old.first['parking_json'])
            : jsonEncode(parking.toMap()),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> saveSnapshot(
    String userId,
    List<Parking> favorites, {
    required DateTime requestedAt,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final pending = await txn.query(
        'pending_favorite_actions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final pendingIds = pending
          .map((row) => row['parking_id'] as String)
          .toSet();
      final old = await txn.query(
        'favorite_cache',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      pendingIds.addAll(
        old
            .where(
              (row) =>
                  DateTime.parse(row['updated_at'] as String)
                      .isAfter(requestedAt),
            )
            .map((row) => row['parking_id'] as String),
      );
      for (final row in old) {
        if (!pendingIds.contains(row['parking_id'])) {
          await txn.delete(
            'favorite_cache',
            where: 'user_id = ? AND parking_id = ?',
            whereArgs: [userId, row['parking_id']],
          );
        }
      }
      final now = DateTime.now().toUtc().toIso8601String();
      for (final parking in favorites) {
        if (pendingIds.contains(parking.id)) continue;
        await txn.insert('favorite_cache', {
          'user_id': userId,
          'parking_id': parking.id,
          'is_favorite': 1,
          'parking_json': jsonEncode(parking.toMap()),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('favorite_snapshot_metadata', {
        'user_id': userId,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> setDesired(
    String userId,
    String parkingId,
    bool value,
    Parking? parking,
  ) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final old = await txn.query(
        'favorite_cache',
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, parkingId],
      );
      final parkingJson = parking == null
          ? (old.isEmpty ? null : old.first['parking_json'])
          : jsonEncode(parking.toMap());
      if (value && parkingJson == null) {
        throw StateError(
          'Open the parking details before saving this favorite offline.',
        );
      }
      await txn.insert('favorite_cache', {
        'user_id': userId,
        'parking_id': parkingId,
        'is_favorite': value ? 1 : 0,
        'parking_json': parkingJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('pending_favorite_actions', {
        'action_id': newClientId(),
        'user_id': userId,
        'parking_id': parkingId,
        'desired_state': value ? 1 : 0,
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Map<String, Object?>>> due(String userId) async {
    final db = await _database.database;
    return db.query(
      'pending_favorite_actions',
      where: 'user_id = ? AND next_attempt_ms <= ?',
      whereArgs: [userId, DateTime.now().millisecondsSinceEpoch],
      orderBy: 'created_at_ms ASC',
      limit: 50,
    );
  }

  Future<void> acknowledge(String actionId, String userId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final actions = await txn.query(
        'pending_favorite_actions',
        where: 'action_id = ? AND user_id = ?',
        whereArgs: [actionId, userId],
      );
      if (actions.isEmpty) return;
      await txn.update(
        'favorite_cache',
        {'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'user_id = ? AND parking_id = ?',
        whereArgs: [userId, actions.first['parking_id']],
      );
      await txn.delete(
        'pending_favorite_actions',
        where: 'action_id = ? AND user_id = ?',
        whereArgs: [actionId, userId],
      );
    });
  }

  Future<void> postpone(String actionId, int attempts) async {
    final db = await _database.database;
    final seconds = (5 * (1 << attempts.clamp(0, 6))).clamp(5, 300).toInt();
    await db.update(
      'pending_favorite_actions',
      {
        'attempt_count': attempts + 1,
        'next_attempt_ms': DateTime.now()
            .add(Duration(seconds: seconds))
            .millisecondsSinceEpoch,
      },
      where: 'action_id = ?',
      whereArgs: [actionId],
    );
  }
}
