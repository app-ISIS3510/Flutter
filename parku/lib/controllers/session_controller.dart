import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/session_service.dart';
import '../state/session_state.dart';

class SessionController {
  static String messageFor(Object error) {
    if (error is AuthException) return 'Sign in to start parking.';
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
    return 'Could not start parking. Check your connection and try again.';
  }

  final SessionService service;
  final SessionState sessionState;

  SessionController(this.service, this.sessionState);

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) async {
    final session = await service.startParking(
      parkingId: parkingId,
      pickupTime: pickupTime,
      vehicleId: vehicleId,
    );

    sessionState.setActiveSession(session);
    return session;
  }

  Future<ParkingSession?> loadActiveSession() async {
    final session = await service.getActiveSession();
    sessionState.setActiveSession(session);
    return session;
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) async {
    final session = await service.changePickupTime(
      sessionId: sessionId,
      pickupTime: pickupTime,
    );

    sessionState.setActiveSession(session);
    return session;
  }

  Future<ParkingSession> endParking({required String sessionId}) async {
    final session = await service.endParking(sessionId: sessionId);
    sessionState.clearSession();
    return session;
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}
