import 'dart:convert';
import 'dart:io';

import 'package:parku/models/analytics_measurements.dart';
import 'package:parku/models/pending_analytics_event.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  var checks = 0;
  for (final source in ['network', 'sqlite', 'memory', 'mixed']) {
    final load = ScreenLoadMeasurement();
    final metadata = load.finish(source: source)!;
    final duration = metadata['duration_ms'] as num;
    check(
      duration >= 0 && duration.isFinite,
      'Load durations must be numeric, nonnegative milliseconds.',
    );
    check(
      metadata['is_from_cache'] == (source != 'network'),
      'Cached and mixed sources must be distinguishable from network-only reads.',
    );
    for (var rebuild = 0; rebuild < 100; rebuild++) {
      check(
        load.finish(source: source) == null,
        'Rebuilds and later responses must not duplicate a completed measurement.',
      );
      checks++;
    }
    final occurredAt = DateTime.utc(2026, 10, 30, 10);
    final queued = PendingAnalyticsEvent(
      id: 'event-$source',
      userId: 'original-user',
      eventType: 'screen_load_completed',
      screen: 'parking_detail',
      parkingId: 'parking-a',
      metadata: {
        ...metadata,
        'device_model': 'SM-EXAMPLE',
        'os_version': '15',
        'os_name': 'android',
        'platform': 'flutter',
      },
      createdAt: occurredAt,
    );
    final persisted =
        jsonDecode(jsonEncode(queued.toLocalMap())) as Map<String, dynamic>;
    final restored = PendingAnalyticsEvent.fromLocalMap(persisted);
    check(
      restored.userId == 'original-user' && restored.createdAt == occurredAt,
      'Offline persistence must preserve the original user and occurrence time.',
    );
    check(
      restored.metadata['duration_ms'] == duration &&
          restored.metadata['is_from_cache'] == metadata['is_from_cache'] &&
          restored.metadata['device_model'] == 'SM-EXAMPLE',
      'The JSON queue must retain duration types, cache flags, and device labels.',
    );
    checks += 4;
  }
  final abandoned = ScreenLoadMeasurement();
  abandoned.cancel();
  check(
    abandoned.finish(source: 'network') == null,
    'Leaving a screen before readiness must not create a successful load.',
  );
  final failed = ScreenLoadMeasurement(trigger: 'refresh');
  final failure = failed.finish(source: 'none', failed: true)!;
  check(
    failure['load_status'] == 'error' && failure['load_trigger'] == 'refresh',
    'Errors and retries must not be mixed with successful initial navigation.',
  );
  checks += 2;

  final visit = ParkingDetailVisit('parking-a');
  check(
    visit.favoriteMetadata(true)['details_viewed'] == false,
    'An addition without presented details must not qualify as a BQ10 conversion.',
  );
  final viewed = visit.markViewed()!;
  check(
    viewed['event_schema_version'] == 2,
    'New actual views need an explicit contract version.',
  );
  for (var refresh = 0; refresh < 100; refresh++) {
    check(
      visit.markViewed() == null,
      'Refreshing or rebuilding the same detail visit must not record another view.',
    );
    checks++;
  }
  final added = visit.favoriteMetadata(true);
  check(
    added['details_viewed'] == true &&
        added['detail_view_id'] == viewed['detail_view_id'],
    'A conversion must link to the actual detail visit.',
  );
  check(
    added['previous_is_favorite'] == false &&
        added['is_favorite'] == true &&
        added['favorite_persistence'] == 'local_pending_sync',
    'The event must describe the saved transition, without claiming server synchronization.',
  );
  final removed = visit.favoriteMetadata(false);
  check(
    removed['is_favorite'] == false && removed['previous_is_favorite'] == true,
    'Removing a favorite must remain distinguishable from adding one.',
  );
  final reopened = ParkingDetailVisit('parking-a');
  check(
    reopened.id != visit.id && !reopened.hasBeenViewed,
    'Reopening the same parking lot must start a separate visit.',
  );
  final other = ParkingDetailVisit('parking-b');
  check(
    other.id != visit.id && other.parkingId != visit.parkingId,
    'Visits to different parking lots must remain separate.',
  );
  final favorite = PendingAnalyticsEvent(
    id: 'addition',
    userId: 'original-user',
    eventType: 'favorite_added',
    screen: 'parking_detail',
    parkingId: visit.parkingId,
    metadata: added,
    createdAt: DateTime.utc(2026, 10, 30),
  );
  final restoredFavorite = PendingAnalyticsEvent.fromLocalMap(
    favorite.toLocalMap(),
  );
  check(
    restoredFavorite.parkingId == 'parking-a' &&
        restoredFavorite.metadata['detail_view_id'] == visit.id &&
        restoredFavorite.metadata['details_viewed'] == true,
    'Queued BQ10 events must retain their join keys after an offline restart.',
  );
  checks += 8;
  stdout.writeln(
    '$checks BQ8/BQ10 event checks passed: duration and cache metadata, no duplicate completion, cancellation, visit attribution, and offline JSON persistence.',
  );
}
