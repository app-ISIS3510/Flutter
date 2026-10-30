import '../utils/client_id.dart';

/// One measurement of time to the first presented primary content, not HTTP
/// latency. Background refreshes must not complete it a second time.
class ScreenLoadMeasurement {
  final String id = newClientId();
  final String trigger;
  final Stopwatch _clock = Stopwatch()..start();
  bool _finished = false;

  ScreenLoadMeasurement({this.trigger = 'navigation'});

  Map<String, dynamic>? finish({required String source, bool failed = false}) {
    if (_finished) return null;
    _finished = true;
    _clock.stop();
    return {
      'event_schema_version': 2,
      'screen_load_id': id,
      'duration_ms': _clock.elapsedMicroseconds / 1000,
      'load_trigger': trigger,
      'load_scope': 'primary_content',
      'load_status': failed ? 'error' : 'success',
      'cache_source': source,
      'is_from_cache':
          source == 'memory' || source == 'sqlite' || source == 'mixed',
    };
  }

  void cancel() {
    _finished = true;
    _clock.stop();
  }
}

/// A visit is shared by the detail screen and its favorite action. The ID is
/// stable across rebuilds and refreshes, and changes when opening another visit.
class ParkingDetailVisit {
  final String id = newClientId();
  final String parkingId;
  bool _viewed = false;

  ParkingDetailVisit(this.parkingId);
  bool get hasBeenViewed => _viewed;

  Map<String, dynamic>? markViewed() {
    if (_viewed) return null;
    _viewed = true;
    return {'event_schema_version': 2, 'detail_view_id': id};
  }

  Map<String, dynamic> favoriteMetadata(bool isFavorite) => {
    'event_schema_version': 2,
    'detail_view_id': id,
    'details_viewed': _viewed,
    'previous_is_favorite': !isFavorite,
    'is_favorite': isFavorite,
    'favorite_persistence': 'local_pending_sync',
  };
}
