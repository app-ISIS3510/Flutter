import '../models/parking_session.dart';
import '../repositories/session_repository.dart';

class SessionService {
  final SessionRepository repository;

  SessionService(this.repository);

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
  }) {
    return repository.createSession(
      parkingId: parkingId,
      pickupTime: pickupTime,
    );
  }

  Future<ParkingSession?> getActiveSession() {
    return repository.getActiveSession();
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) {
    return repository.updatePickupTime(
      sessionId: sessionId,
      pickupTime: pickupTime,
    );
  }

  Future<ParkingSession> endParking({
    required String sessionId,
  }) {
    return repository.endSession(
      sessionId: sessionId,
    );
  }

  Future<bool> hasActiveSession() {
    return repository.hasActiveSession();
  }
  
}