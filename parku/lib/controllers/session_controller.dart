import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/session_service.dart';
import '../state/session_state.dart';
import '../utils/user_error_message.dart';

class SessionController {
  static String messageFor(Object error) =>
      userErrorMessage(error, action: ErrorAction.startParking);

  final SessionService service;
  final SessionState sessionState;
  int _stateVersion = 0;

  SessionController(this.service, this.sessionState);

  void _checkUser(String? userId) {
    if (service.currentUserId != userId) {
      throw const AuthException('The signed-in account changed.');
    }
  }

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) async {
    final userId = service.currentUserId;
    _stateVersion++;
    final session = await service.startParking(
      parkingId: parkingId,
      pickupTime: pickupTime,
      vehicleId: vehicleId,
    );

    _checkUser(userId);
    sessionState.setActiveSession(session);
    return session;
  }

  Future<ParkingSession?> loadActiveSession() async {
    final userId = service.currentUserId;
    final version = _stateVersion;
    final session = await service.getActiveSession();
    _checkUser(userId);
    if (version == _stateVersion) {
      sessionState.setActiveSession(
        session,
        isFromCache: service.lastReadFromCache,
      );
    }
    return session;
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) async {
    final userId = service.currentUserId;
    _stateVersion++;
    final session = await service.changePickupTime(
      sessionId: sessionId,
      pickupTime: pickupTime,
    );

    _checkUser(userId);
    sessionState.setActiveSession(session);
    return session;
  }

  Future<ParkingSession> endParking({required String sessionId}) async {
    final userId = service.currentUserId;
    _stateVersion++;
    final session = await service.endParking(sessionId: sessionId);
    _checkUser(userId);
    sessionState.clearSession();
    return session;
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}
