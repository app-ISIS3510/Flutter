import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/session_service.dart';

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

  SessionController(this.service);

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) {
    return service.startParking(
      parkingId: parkingId,
      pickupTime: pickupTime,
      vehicleId: vehicleId,
    );
  }

  Future<ParkingSession?> loadActiveSession() {
    return service.getActiveSession();
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) {
    return service.changePickupTime(
      sessionId: sessionId,
      pickupTime: pickupTime,
    );
  }

  Future<ParkingSession> endParking({required String sessionId}) {
    return service.endParking(sessionId: sessionId);
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}
