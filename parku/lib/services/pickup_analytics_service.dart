import 'dart:async';

import '../models/parking_session.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/user_local_store.dart';

class PickupAnalyticsService {
  final AnalyticsRepository repository;
  final UserLocalStore store;
  final Duration timeout;
  Future<void> _writing = Future<void>.value();
  Future<bool>? _sending;
  String? _sendingUser;
  bool saveFailed = false;

  PickupAnalyticsService(
    this.repository,
    this.store, {
    this.timeout = const Duration(seconds: 8),
  });

  Future<void> _editQueue(Future<void> Function() action) {
    final next = _writing.then((_) => action());
    _writing = next.catchError((Object _) {});
    return next;
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final saved = await store.read('pickup_analytics');
    return List<Map<String, dynamic>>.from(saved?['events'] as List? ?? []);
  }

  Future<void> saveChoice(
    ParkingSession session,
    Map<String, dynamic> request,
  ) async {
    final selected = DateTime.tryParse(request['pickup_time'] as String? ?? '');
    final suggested = DateTime.tryParse(
      request['suggested_pickup_time'] as String? ?? '',
    );
    if (selected == null || suggested == null) return;
    final owner = store.userId;
    if (session.userId != owner) return;
    final event = <String, dynamic>{
      'id': session.id,
      'user_id': owner,
      'event_type': 'parking_pickup_choice',
      'screen': 'pickup_time',
      'parking_id': session.parkingId,
      'created_at': session.startedAt.toUtc().toIso8601String(),
      'metadata': {
        'session_id': session.id,
        'platform': 'flutter',
        'pickup_selection': selected.isAtSameMomentAs(suggested)
            ? 'suggested'
            : 'manual',
        'suggested_pickup_time': suggested.toUtc().toIso8601String(),
        'selected_pickup_time': selected.toUtc().toIso8601String(),
      },
    };
    try {
      await _editQueue(() async {
        store.checkUser(owner);
        final events = await _read();
        store.checkUser(owner);
        if (!events.any((saved) => saved['id'] == event['id'])) {
          events.add(event);
          await store.write('pickup_analytics', {'events': events});
        }
      });
      saveFailed = false;
    } catch (_) {
      saveFailed = true;
      return;
    }
    unawaited(flush());
  }

  Future<bool> flush() {
    final owner = repository.userId;
    if (owner == null) return Future.value(false);
    if (_sending != null) {
      if (_sendingUser == owner) return _sending!;
      return _sending!.then((_) => flush());
    }
    final sending = _flush();
    _sending = sending;
    _sendingUser = owner;
    unawaited(
      sending.then((_) {
        if (identical(_sending, sending)) {
          _sending = null;
          _sendingUser = null;
        }
      }),
    );
    return sending;
  }

  Future<bool> _flush() async {
    try {
      final owner = store.userId;
      while (true) {
        var queued = <Map<String, dynamic>>[];
        await _editQueue(() async {
          store.checkUser(owner);
          queued = await _read();
          store.checkUser(owner);
        });
        if (queued.isEmpty) return true;
        for (final event in queued) {
          store.checkUser(owner);
          await repository.savePickupChoice(event).timeout(timeout);
          store.checkUser(owner);
          await _editQueue(() async {
            store.checkUser(owner);
            final remaining = await _read();
            store.checkUser(owner);
            remaining.removeWhere((saved) => saved['id'] == event['id']);
            await store.write('pickup_analytics', {'events': remaining});
          });
        }
      }
    } catch (_) {
      return false;
    }
  }
}
