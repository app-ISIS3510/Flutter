import '../models/parking_session.dart';
import '../services/session_service.dart';

class SessionController {
  final SessionService service;

  SessionController(this.service);

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
  }) {
    return service.startParking(
      parkingId: parkingId,
      pickupTime: pickupTime,
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

  Future<ParkingSession> endParking({
    required String sessionId,
  }) {
    return service.endParking(
      sessionId: sessionId,
    );
  }

  Future<bool> hasActiveSession() {
    return service.hasActiveSession();
  }
}