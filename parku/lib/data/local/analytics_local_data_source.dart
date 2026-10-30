import '../../models/pending_analytics_event.dart';
import 'app_database.dart';

class AnalyticsLocalDataSource {
  final AppDatabase _database;

  AnalyticsLocalDataSource({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  Future<void> enqueue(PendingAnalyticsEvent event) async {
    final record = event.toLocalMap();
    final db = await _database.database;
    await db.insert('pending_analytics_events', record);
  }

  Future<List<PendingAnalyticsEvent>> readDue(String userId) async {
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
