import '../models/parking_session.dart';
import '../models/parking_summary.dart';
import '../repositories/session_history_repository.dart';
import '../repositories/session_repository.dart';

class SessionService {
  final SessionRepository repository;
  final SessionHistoryRepository historyRepository;
  bool historySaveFailed = false;

  SessionService(this.repository, {SessionHistoryRepository? historyRepository})
    : historyRepository =
          historyRepository ?? SessionHistoryRepository(repository.client);

  bool get historyAvailable => historyRepository.isAvailable;

  Future<List<ParkingSummary>> getSavedSessions() {
    return historyRepository.getSavedSessions();
  }

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) {
    return repository.createSession(
      parkingId: parkingId,
      pickupTime: pickupTime,
      vehicleId: vehicleId,
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
    String parkingName = 'Parking stay',
  }) async {
    historySaveFailed = false;
    final session = await repository.endSession(sessionId: sessionId);

    if (historyAvailable) {
      try {
        await historyRepository.saveSummary(
          ParkingSummary.fromSession(session, parkingName: parkingName),
        );
      } catch (_) {
        historySaveFailed = true;
      }
    }

    return session;
  }

  Future<bool> hasActiveSession() {
    return repository.hasActiveSession();
  }
}
