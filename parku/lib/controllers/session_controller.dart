import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/session_service.dart';
import '../services/connection_failure.dart';
import '../state/session_state.dart';
import '../utils/user_error_message.dart';

class SessionController {
  static String messageFor(Object error) {
    if (error is ConnectionFailure) {
      return error.message;
    }

    if (isConnectionError(error)) {
      return 'Could not confirm the request. Reconnect and check '
          'My parking before trying again.';
    }

    return userErrorMessage(
      error,
      action: ErrorAction.startParking,
    );
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

  void _checkUser(String? userId) {
    if (service.currentUserId != userId) {
      throw const AuthException(
        'The signed-in account changed.',
      );
    }
  }

  void clear() {
    _version++;
    _busyVersion = null;
    _loading = null;
    _loadingVersion = null;
    _loadingUser = null;
    service.clear();
    sessionState.clearSession();
  }

  void dispose() {
    _version++;
    _busyVersion = null;
    _loading = null;
    _loadingVersion = null;
    _loadingUser = null;
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
      _checkUser(userId);

      if (version == _version) {
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
  }) {
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
      if (identical(_loading, request)) {
        _loading = null;
      }
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
    _checkUser(userId);

    if (version == _version && _busyVersion == null) {
      sessionState.setActiveSession(
        session,
        isFromCache:
            service.lastReadFromCache || service.usingSavedSession,
      );
    }

    return session;
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    String parkingName = 'Parking stay',
  }) {
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
  }) {
    return _change(
      () => service.endParking(
        sessionId: sessionId,
        parkingName: parkingName,
      ),
    );
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}