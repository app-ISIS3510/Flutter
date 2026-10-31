import 'dart:developer' as developer;
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/analytics_local_data_source.dart';
import '../models/pending_analytics_event.dart';
import '../models/pickup_choice_summary.dart';
import '../utils/client_id.dart';

class AnalyticsRepository {
  final SupabaseClient client;
  final AnalyticsLocalDataSource localDataSource;

  Future<void>? _flushFuture;

  AnalyticsRepository(
    this.client, {
    AnalyticsLocalDataSource? localDataSource,
  }) : localDataSource =
           localDataSource ?? AnalyticsLocalDataSource();

  String? get userId => client.auth.currentUser?.id;

  Future<PickupChoiceSummary> getPickupChoices() async {
    final owner = userId;
    if (owner == null) throw const AuthException('Sign in to continue.');
    final rows = await client
        .from('bq9_pickup_time_choice_last_7_days')
        .select(
          'pickup_choice,successful_starts,percentage,total_successful_starts',
        );
    if (userId != owner) {
      throw const AuthException('The signed-in account changed.');
    }
    return PickupChoiceSummary.fromRows(rows, updatedAt: DateTime.now().toUtc());
  }

  Future<void> savePickupChoice(
    Map<String, dynamic> event,
  ) async {
    final currentUserId = userId;

    if (currentUserId == null ||
        currentUserId != event['user_id']) {
      throw const AuthException(
        'The signed-in account changed.',
      );
    }

    await client
        .from('analytics_events')
        .upsert(
          event,
          onConflict: 'id',
          ignoreDuplicates: true,
        );
  }

  Future<void> trackEvent({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) async {
    final currentUserId = userId;
    if (currentUserId == null) return;

    await localDataSource.enqueue(
      PendingAnalyticsEvent(
        id: newClientId(),
        userId: currentUserId,
        eventType: eventType,
        screen: screen,
        parkingId: parkingId,
        metadata: {
          'platform': 'flutter',
          ...?metadata,
        },
        createdAt: occurredAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> flushPending() {
    return _flushFuture ??=
        _flush().whenComplete(() => _flushFuture = null);
  }

  Future<void> _flush() async {
    final owner = userId;
    if (owner == null) return;

    while (userId == owner) {
      final events = await localDataSource.readDue(owner);
      if (events.isEmpty) return;

      for (final event in events) {
        if (userId != owner) return;

        try {
          await client
              .from('analytics_events')
              .upsert(
                event.payload,
                onConflict: 'id',
                ignoreDuplicates: true,
              )
              .timeout(const Duration(seconds: 10));

          await localDataSource.acknowledge(event);
        } catch (error, stackTrace) {
          final delaySeconds = min(
            300,
            5 * (1 << min(event.attempts, 6)),
          );

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
