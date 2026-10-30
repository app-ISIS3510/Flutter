import 'package:sqflite/sqflite.dart';

import '../../models/parking_session.dart';
import 'app_database.dart';

class SessionLocalDataSource {
  final AppDatabase _database;

  SessionLocalDataSource({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  Future<void> saveConfirmed(String userId, ParkingSession session) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('confirmed_sessions_cache', {
        ...session.toMap(),
        'user_id': userId,
        'confirmed_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (session.status == 'active') {
        await txn.insert('session_snapshot_metadata', {
          'user_id': userId,
          'active_session_id': session.id,
          'checked_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.update(
          'session_snapshot_metadata',
          {'active_session_id': null, 'checked_at': now},
          where: 'user_id = ? AND active_session_id = ?',
          whereArgs: [userId, session.id],
        );
      }
    });
  }

  Future<void> saveNoActiveSession(String userId) async {
    final db = await _database.database;
    await db.insert('session_snapshot_metadata', {
      'user_id': userId,
      'active_session_id': null,
      'checked_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<({bool hasSnapshot, ParkingSession? session})> readActive(
    String userId,
  ) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final metadata = await txn.query(
        'session_snapshot_metadata',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (metadata.isEmpty) return (hasSnapshot: false, session: null);
      final id = metadata.first['active_session_id'];
      if (id == null) return (hasSnapshot: true, session: null);
      final rows = await txn.query(
        'confirmed_sessions_cache',
        where: 'user_id = ? AND id = ?',
        whereArgs: [userId, id],
      );
      if (rows.isEmpty) return (hasSnapshot: false, session: null);
      return (
        hasSnapshot: true,
        session: ParkingSession.fromMap(
          rows.first,
          isFromCache: true,
          confirmedAt: DateTime.parse(rows.first['confirmed_at'] as String),
        ),
      );
    });
  }
}
