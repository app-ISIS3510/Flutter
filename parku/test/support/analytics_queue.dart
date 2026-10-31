import 'package:parku/data/local/analytics_local_data_source.dart';
import 'package:parku/models/pending_analytics_event.dart';

/// Keeps an inspection journal even after events are acknowledged by the API.
class TestAnalyticsQueue extends AnalyticsLocalDataSource {
  final events = <PendingAnalyticsEvent>[];
  final _pending = <String, Map<String, Object?>>{};
  bool unavailable = false;

  @override
  Future<void> enqueue(PendingAnalyticsEvent event) async {
    if (unavailable) throw StateError('Storage unavailable');
    events.add(event);
    _pending[event.id] = event.toLocalMap();
  }

  @override
  Future<List<PendingAnalyticsEvent>> readDue(String userId) async => _pending
      .values
      .where(
        (row) =>
            row['user_id'] == userId &&
            (row['next_attempt_ms'] as int) <=
                DateTime.now().millisecondsSinceEpoch,
      )
      .map(PendingAnalyticsEvent.fromLocalMap)
      .toList();

  @override
  Future<void> acknowledge(PendingAnalyticsEvent event) async {
    if (_pending[event.id]?['user_id'] == event.userId) {
      _pending.remove(event.id);
    }
  }

  @override
  Future<void> recordFailure(
    PendingAnalyticsEvent event, {
    required int nextAttemptMs,
    required String errorCode,
  }) async {
    final row = _pending[event.id];
    if (row == null || row['user_id'] != event.userId) return;
    row['attempt_count'] = event.attempts + 1;
    row['next_attempt_ms'] = nextAttemptMs;
    row['last_error'] = errorCode;
  }
}
