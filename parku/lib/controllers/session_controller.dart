import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/session_service.dart';
import '../state/session_state.dart';
import '../services/connection_failure.dart';

class SessionController {
  static String messageFor(Object error) {
    if (error is ConnectionFailure) return error.message;
    if (isConnectionError(error)) {
      return 'Could not reach the server. Your selection has been kept. Reconnect and try again.';
    }
    if (error is AuthException) return 'Sign in to continue.';
    if (error is FormatException) return error.message;
    if (error is PostgrestException) {
      if (error.message.contains('NO_AVAILABLE_SPACES')) {
        return 'This parking lot has no available spaces.';
      }
      if (error.message.contains('ACTIVE_SESSION_EXISTS')) {
        return 'You already have an active parking session. Open My parking.';
      }
      if (error.message.contains('VEHICLE_NOT_FOUND')) {
        return 'This vehicle is no longer available. Choose another vehicle.';
      }
      if (error.message.contains('INVALID_PICKUP_TIME')) {
        return 'Choose a pickup time later than the current time.';
      }
    }
    return 'Could not complete this request. Check your connection and try again.';
  }

  final SessionService service;
  final SessionState sessionState;
  int _version = 0;
  int? _busyVersion;
  Future<ParkingSession?>? _loading;
  int? _loadingVersion;
  String? _loadingUser;
  bool get busy => _busyVersion != null;

  SessionController(this.service, this.sessionState);

  void clear() {
    _version++;
    _busyVersion = null;
    service.clear();
    sessionState.clearSession();
  }

  void dispose() {
    _version++;
    _busyVersion = null;
  }

  Future<ParkingSession> _change(
    Future<ParkingSession> Function() action,
  ) async {
    if (_busyVersion != null) {
      throw const ConnectionFailure(
        'A parking request is already being checked. Please wait.',
      );
    }
    final version = ++_version;
    final userId = service.currentUserId;
    _busyVersion = version;
    try {
      final session = await action();
      if (version == _version && userId == service.currentUserId) {
        sessionState.setActiveSession(
          session.status == 'active' ? session : null,
        );
      }
      return session;
    } finally {
      if (_busyVersion == version) {
        _busyVersion = null;
        _version++;
      }
    }
  }

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
    String parkingName = 'Parking stay',
    DateTime? suggestedPickupTime,
  }) async {
    return _change(
      () => service.startParking(
        parkingId: parkingId,
        pickupTime: pickupTime,
        vehicleId: vehicleId,
        parkingName: parkingName,
        suggestedPickupTime: suggestedPickupTime,
      ),
    );
  }

  Future<ParkingSession?> loadActiveSession() {
    final version = _version;
    final userId = service.currentUserId;
    if (_loading != null &&
        _loadingVersion == version &&
        _loadingUser == userId) {
      return _loading!;
    }
    final request = _loadActiveSession(version, userId);
    _loading = request;
    _loadingVersion = version;
    _loadingUser = userId;
    void finished() {
      if (identical(_loading, request)) _loading = null;
    }

    unawaited(
      request.then<void>(
        (_) => finished(),
        onError: (Object _, StackTrace _) => finished(),
      ),
    );
    return request;
  }

  Future<ParkingSession?> _loadActiveSession(
    int version,
    String? userId,
  ) async {
    final session = await service.getActiveSession();
    if (version == _version &&
        userId == service.currentUserId &&
        _busyVersion == null) {
      sessionState.setActiveSession(session);
    }
    return session;
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    String parkingName = 'Parking stay',
  }) async {
    return _change(
      () => service.changePickupTime(
        sessionId: sessionId,
        pickupTime: pickupTime,
        parkingName: parkingName,
      ),
    );
  }

  Future<ParkingSession> endParking({
    required String sessionId,
    String parkingName = 'Parking stay',
  }) async {
    return _change(
      () => service.endParking(sessionId: sessionId, parkingName: parkingName),
    );
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}
