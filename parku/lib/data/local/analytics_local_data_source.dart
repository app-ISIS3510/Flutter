import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/pending_analytics_event.dart';
import '../../utils/async_operations.dart';
import 'app_database.dart';

class AnalyticsLocalDataSource {
  final AppDatabase _database;
  final _BrowserAnalyticsQueue? _browser;

  AnalyticsLocalDataSource({
    AppDatabase? database,
    SharedPreferences? browserPreferences,
  }) : _database = database ?? AppDatabase.instance,
       _browser = kIsWeb || browserPreferences != null
           ? _BrowserAnalyticsQueue(browserPreferences)
           : null;

  Future<void> enqueue(PendingAnalyticsEvent event) async {
    if (_browser != null) return _browser.enqueue(event);
    final record = event.toLocalMap();
    final db = await _database.database;
    await db.insert('pending_analytics_events', record);
  }

  Future<List<PendingAnalyticsEvent>> readDue(String userId) async {
    if (_browser != null) return _browser.readDue(userId);
    final db = await _database.database;
    final rows = await db.query(
      'pending_analytics_events',
      where: 'user_id = ? AND next_attempt_ms <= ?',
      whereArgs: [userId, DateTime.now().millisecondsSinceEpoch],
      orderBy: 'created_at_ms ASC, rowid ASC',
      limit: 50,
    );
    return rows.map(PendingAnalyticsEvent.fromLocalMap).toList();
  }

  Future<void> acknowledge(PendingAnalyticsEvent event) async {
    if (_browser != null) return _browser.acknowledge(event);
    final db = await _database.database;
    await db.delete(
      'pending_analytics_events',
      where: 'id = ? AND user_id = ?',
      whereArgs: [event.id, event.userId],
    );
  }

  Future<void> recordFailure(
    PendingAnalyticsEvent event, {
    required int nextAttemptMs,
    required String errorCode,
  }) async {
    if (_browser != null) {
      return _browser.recordFailure(
        event,
        nextAttemptMs: nextAttemptMs,
        errorCode: errorCode,
      );
    }
    final db = await _database.database;
    await db.update(
      'pending_analytics_events',
      {
        'attempt_count': event.attempts + 1,
        'next_attempt_ms': nextAttemptMs,
        'last_error': errorCode,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [event.id, event.userId],
    );
  }
}

/// Mirrors the mobile pending queue using persistent browser storage.
class _BrowserAnalyticsQueue {
  static const _key = 'parku.pending_analytics.v1';
  static final _operations = AsyncSerialExecutor();
  final SharedPreferences? _preferences;
  _BrowserAnalyticsQueue(this._preferences);

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<List<Map<String, Object?>>> _read() async {
    final json = (await _prefs).getString(_key);
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .map((row) => Map<String, Object?>.from(row as Map))
        .toList();
  }

  Future<void> _save(List<Map<String, Object?>> rows) async {
    if (!await (await _prefs).setString(_key, jsonEncode(rows))) {
      throw StateError('Could not save pending analytics.');
    }
  }

  Future<void> enqueue(PendingAnalyticsEvent event) =>
      _operations.run(() async {
        final rows = await _read();
        if (!rows.any((row) => row['id'] == event.id)) {
          rows.add(event.toLocalMap());
        }
        await _save(rows);
      });

  Future<List<PendingAnalyticsEvent>> readDue(String userId) =>
      _operations.run(() async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final rows =
            (await _read())
                .asMap()
                .entries
                .where(
                  (entry) =>
                      entry.value['user_id'] == userId &&
                      (entry.value['next_attempt_ms'] as int) <= now,
                )
                .toList()
              ..sort((a, b) {
                final time = (a.value['created_at_ms'] as int).compareTo(
                  b.value['created_at_ms'] as int,
                );
                return time == 0 ? a.key.compareTo(b.key) : time;
              });
        return rows
            .take(50)
            .map((entry) => PendingAnalyticsEvent.fromLocalMap(entry.value))
            .toList();
      });

  Future<void> acknowledge(PendingAnalyticsEvent event) =>
      _operations.run(() async {
        final rows = await _read();
        rows.removeWhere(
          (row) => row['id'] == event.id && row['user_id'] == event.userId,
        );
        await _save(rows);
      });

  Future<void> recordFailure(
    PendingAnalyticsEvent event, {
    required int nextAttemptMs,
    required String errorCode,
  }) => _operations.run(() async {
    final rows = await _read();
    for (final row in rows) {
      if (row['id'] == event.id && row['user_id'] == event.userId) {
        row['attempt_count'] = event.attempts + 1;
        row['next_attempt_ms'] = nextAttemptMs;
        row['last_error'] = errorCode;
      }
    }
    await _save(rows);
  });
}
