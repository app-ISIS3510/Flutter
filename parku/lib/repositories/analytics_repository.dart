import 'dart:developer' as developer;
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/analytics_local_data_source.dart';
import '../models/pending_analytics_event.dart';
import '../utils/client_id.dart';

class AnalyticsRepository {
  final SupabaseClient client;
  final AnalyticsLocalDataSource localDataSource;
  Future<void>? _flushFuture;

  AnalyticsRepository(this.client, {AnalyticsLocalDataSource? localDataSource})
    : localDataSource = localDataSource ?? AnalyticsLocalDataSource();

  Future<void> trackEvent({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    await localDataSource.enqueue(
      PendingAnalyticsEvent(
        id: newClientId(),
        userId: userId,
        eventType: eventType,
        screen: screen,
        parkingId: parkingId,
        metadata: {'platform': 'flutter', ...?metadata},
        createdAt: occurredAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> flushPending() {
    return _flushFuture ??= _flush().whenComplete(() => _flushFuture = null);
  }

  Future<void> _flush() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    while (client.auth.currentUser?.id == userId) {
      final events = await localDataSource.readDue(userId);
      if (events.isEmpty) return;
      for (final event in events) {
        if (client.auth.currentUser?.id != userId) return;
        try {
          // Retrying a previously accepted UUID cannot insert the event twice.
          await client
              .from('analytics_events')
              .upsert(event.payload, onConflict: 'id', ignoreDuplicates: true)
              .timeout(const Duration(seconds: 10));
          await localDataSource.acknowledge(event);
        } catch (error, stackTrace) {
          final delaySeconds = min(300, 5 * (1 << min(event.attempts, 6)));
          await localDataSource.recordFailure(
            event,
            nextAttemptMs: DateTime.now()
                .add(Duration(seconds: delaySeconds))
                .millisecondsSinceEpoch,
            errorCode: error is PostgrestException
                ? error.code ?? 'database_error'
                : error.runtimeType.toString(),
          );
          developer.log(
            'Analytics event kept for a later retry',
            name: 'AnalyticsRepository',
            error: error,
            stackTrace: stackTrace,
          );
          // A rejected individual payload must not block later valid events.
          if (error is PostgrestException &&
              ((error.code ?? '').startsWith('22') ||
                  (error.code ?? '').startsWith('23'))) {
            continue;
          }
          return;
        }
      }
    }
  }
}
