import '../models/parking_session.dart';
import '../services/session_service.dart';
import '../state/session_state.dart';

class SessionController {
  final SessionService service;
  final SessionState sessionState;

  SessionController(
    this.service,
    this.sessionState,
  );

  Future<ParkingSession?> loadActiveSession() async {
    final session =
        await service.getActiveSession();

    sessionState.setActiveSession(session);

    return session;
  }

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
  }) async {
    final session =
        await service.startParking(
      parkingId: parkingId,
      pickupTime: pickupTime,
    );

    sessionState.setActiveSession(session);

    return session;
  }

  Future<void> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) async {
    await service.changePickupTime(
      sessionId: sessionId,
      pickupTime: pickupTime,
    );

    final refreshedSession =
        await service.getActiveSession();

    sessionState.setActiveSession(
      refreshedSession,
    );
  }

  Future<void> endParking(
    String sessionId,
  ) async {
    await service.endParking(sessionId: sessionId);

    sessionState.clearSession();
  }

  Future<bool> hasActiveSession() async {
  return await service.hasActiveSession();
}
}