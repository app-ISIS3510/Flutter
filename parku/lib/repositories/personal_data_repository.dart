import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';

class PersonalDataRepository {
  final DatabaseFactory? factory;
  final String? databasePath;
  Future<Database>? _opening;

  PersonalDataRepository({this.factory, this.databasePath});

  Future<Database> _database() async {
    final opening = _opening ??= _open();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path =
        databasePath ??
        '${(await getApplicationSupportDirectory()).path}/parku_personal.db';
    return (factory ?? databaseFactory).openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE profiles (
              user_id TEXT PRIMARY KEY,
              full_name TEXT NOT NULL,
              email TEXT NOT NULL,
              pending_email TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE vehicles (
              user_id TEXT NOT NULL,
              id TEXT NOT NULL,
              vehicle_type TEXT NOT NULL,
              plate TEXT NOT NULL,
              is_selected INTEGER NOT NULL,
              PRIMARY KEY (user_id, id)
            )
          ''');
          await db.execute('''
            CREATE TABLE vehicle_sync (
              user_id TEXT PRIMARY KEY
            )
          ''');
          await db.execute('''
            CREATE TABLE active_sessions (
              user_id TEXT PRIMARY KEY,
              session_json TEXT NOT NULL
            )
          ''');
        },
      ),
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (kIsWeb) return;
    final db = await _database();
    await db.insert('profiles', {
      'user_id': profile.id,
      'full_name': profile.fullName,
      'email': profile.email,
      'pending_email': profile.pendingEmail,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<UserProfile?> getProfile(String userId) async {
    if (kIsWeb) return null;
    final db = await _database();
    final rows = await db.query(
      'profiles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return UserProfile(
      id: userId,
      fullName: row['full_name'] as String,
      email: row['email'] as String,
      pendingEmail: row['pending_email'] as String?,
    );
  }

  Future<void> saveVehicles(String userId, List<Vehicle> vehicles) async {
    if (kIsWeb) return;
    final db = await _database();
    await db.transaction((transaction) async {
      await transaction.delete(
        'vehicles',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final vehicle in vehicles) {
        await transaction.insert('vehicles', {
          'user_id': userId,
          'id': vehicle.id,
          'vehicle_type': vehicle.type.value,
          'plate': vehicle.plate,
          'is_selected': vehicle.isSelected ? 1 : 0,
        });
      }
      await transaction.insert('vehicle_sync', {
        'user_id': userId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<Vehicle>?> getVehicles(String userId) async {
    if (kIsWeb) return null;
    final db = await _database();
    final synced = await db.query(
      'vehicle_sync',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (synced.isEmpty) return null;
    final rows = await db.query(
      'vehicles',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows
        .map(
          (row) =>
              Vehicle.fromMap({...row, 'is_selected': row['is_selected'] == 1}),
        )
        .toList();
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }

  Future<void> saveActiveSession(String userId, ParkingSession? session) async {
    if (kIsWeb) return;
    final db = await _database();
    if (session == null) {
      await db.delete(
        'active_sessions',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return;
    }
    await db.insert('active_sessions', {
      'user_id': userId,
      'session_json': jsonEncode(session.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ParkingSession?> getActiveSession(String userId) async {
    if (kIsWeb) return null;
    final db = await _database();
    final rows = await db.query(
      'active_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return null;
    return ParkingSession.fromMap(
      jsonDecode(rows.single['session_json'] as String) as Map<String, dynamic>,
    );
  }
}
