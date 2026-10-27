import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/parking.dart';
import '../models/parking_session.dart';
import '../models/parking_summary.dart';
import '../repositories/session_history_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_local_store.dart';
import '../repositories/personal_data_repository.dart';
import 'connection_failure.dart';

class SessionService {
  final SessionRepository repository;
  final SessionHistoryRepository historyRepository;
  final UserLocalStore? store;
  final PersonalDataRepository? local;
  final Duration requestTimeout;
  bool historySaveFailed = false;
  bool localSaveFailed = false;
  bool usingSavedSession = false;
  bool recoveredRequest = false;
  Map<String, dynamic>? pendingRequest;
  final _inFlight = <String, Future<ParkingSession>>{};

  SessionService(
    this.repository, {
    SessionHistoryRepository? historyRepository,
    this.store,
    this.local,
    this.requestTimeout = const Duration(seconds: 8),
  }) : historyRepository =
           historyRepository ?? SessionHistoryRepository(repository.client);

  String? get currentUserId => repository.client.auth.currentUser?.id;
  bool get historyAvailable => historyRepository.isAvailable;

  String? get notice {
    if (pendingRequest != null) {
      return 'Your previous parking request is not confirmed. Refresh to check its status before retrying.';
    }
    if (usingSavedSession) {
      return 'Showing your last confirmed parking data. Reconnect and refresh before making changes.';
    }
    if (localSaveFailed) {
      return 'The offline copy could not be saved on this device.';
    }
    return null;
  }

  String _userId() =>
      currentUserId ?? (throw const AuthException('Sign in to continue.'));

  void _checkUser(String userId) {
    if (currentUserId != userId) {
      throw const AuthException('The signed-in account has changed.');
    }
  }

  void clear() {
    pendingRequest = null;
    usingSavedSession = false;
    recoveredRequest = false;
    localSaveFailed = false;
    historySaveFailed = false;
    _inFlight.clear();
  }

  Future<List<ParkingSummary>> getSavedSessions() =>
      historyRepository.getSavedSessions();

  Future<void> restorePendingRequest() async {
    final owner = _userId();
    final pending = await store?.read('session_request');
    _checkUser(owner);
    pendingRequest = pending;
  }

  Future<void> savePickupDraft(String key, Map<String, dynamic> data) async {
    await store?.write('draft_$key', {
      ...data,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getPickupDraft(String key) async {
    final saved = await store?.read('draft_$key');
    if (saved == null) return null;
    final date = DateTime.tryParse(saved['date'] as String? ?? '')?.toLocal();
    final now = DateTime.now();
    if (date == null ||
        date.year != now.year ||
        date.month != now.month ||
        date.day != now.day) {
      return null;
    }
    return saved;
  }

  Future<void> saveParking(Parking parking) async {
    try {
      await store?.write('parking_${parking.id}', parking.toMap());
    } catch (_) {
      localSaveFailed = true;
    }
  }

  Future<Parking?> getSavedParking(String id) async {
    final saved = await store?.read('parking_$id');
    return saved == null ? null : Parking.fromMap(saved);
  }

  Future<void> _remember(ParkingSession? session, String owner) async {
    _checkUser(owner);
    if (session != null && session.userId != owner) {
      throw const AuthException(
        'This parking session belongs to another user.',
      );
    }
    try {
      final active = session?.status == 'active' ? session : null;
      if (local != null && !kIsWeb) {
        await local!.saveActiveSession(owner, active);
      } else {
        await store?.write('active_session', {'session': active?.toMap()});
      }
    } catch (_) {
      localSaveFailed = true;
    }
    _checkUser(owner);
  }

  Future<void> _saveSummary(ParkingSession session, String name) async {
    historySaveFailed = false;
    if (!historyAvailable) return;
    try {
      await historyRepository.saveSummary(
        ParkingSummary.fromSession(session, parkingName: name),
      );
    } catch (_) {
      historySaveFailed = true;
    }
  }

  Future<ParkingSession> _confirm(
    ParkingSession session,
    Map<String, dynamic> request,
    String owner, {
    bool recovered = false,
  }) async {
    _checkUser(owner);
    await _remember(session, owner);
    if (session.status == 'completed') {
      await _saveSummary(
        session,
        request['parking_name'] as String? ?? 'Parking stay',
      );
    }
    _checkUser(owner);
    try {
      await store?.remove('session_request');
      if (request['kind'] == 'start') {
        await store?.remove('draft_start_${request['parking_id']}');
      }
      if (request['kind'] == 'change') {
        await store?.remove('draft_change_${request['session_id']}');
      }
    } catch (_) {
      localSaveFailed = true;
    }
    _checkUser(owner);
    pendingRequest = null;
    usingSavedSession = false;
    recoveredRequest = recovered;
    return session;
  }

  Future<ParkingSession?> _recover(
    Map<String, dynamic> request,
    String owner,
  ) async {
    ParkingSession? confirmed;
    if (request['kind'] == 'start') {
      final sessions = await repository
          .getMatchingSessions(
            parkingId: request['parking_id'] as String,
            vehicleId: request['vehicle_id'] as String,
            pickupTime: DateTime.parse(request['pickup_time'] as String),
          )
          .timeout(requestTimeout);
      final known = List<String>.from(request['known_ids'] as List? ?? []);
      for (final session in sessions) {
        if (!known.contains(session.id)) {
          confirmed = session;
          break;
        }
      }
    } else {
      final session = await repository
          .getSessionById(request['session_id'] as String)
          .timeout(requestTimeout);
      if (session != null) {
        if (request['kind'] == 'end' && session.status == 'completed') {
          confirmed = session;
        }
        if (request['kind'] == 'change' && session.status == 'completed') {
          confirmed = session;
        }
        if (request['kind'] == 'change' &&
            session.status == 'active' &&
            session.pickupTime.isAtSameMomentAs(
              DateTime.parse(request['pickup_time'] as String),
            )) {
          confirmed = session;
        }
      } else {
        _checkUser(owner);
        await store?.remove('session_request');
        pendingRequest = null;
      }
    }
    _checkUser(owner);
    return confirmed == null
        ? null
        : _confirm(confirmed, request, owner, recovered: true);
  }

  bool _sameRequest(Map<String, dynamic> first, Map<String, dynamic> second) {
    return [
      'kind',
      'parking_id',
      'vehicle_id',
      'pickup_time',
      'session_id',
    ].every((key) => first[key] == second[key]);
  }

  String _requestKey(Map<String, dynamic> request, String owner) => jsonEncode([
    owner,
    request['kind'],
    request['session_id'],
    request['parking_id'],
    request['vehicle_id'],
    request['pickup_time'],
  ]);

  Future<ParkingSession?> _checkPending(
    Map<String, dynamic> next,
    String owner,
  ) async {
    pendingRequest = await store?.read('session_request');
    _checkUser(owner);
    final pending = pendingRequest;
    if (pending == null) return null;
    ParkingSession? confirmed;
    try {
      confirmed = await _recover(pending, owner);
    } catch (error) {
      if (!isConnectionError(error)) rethrow;
      throw const ConnectionFailure(
        'Your previous request is still unconfirmed. Reconnect and check My parking before retrying.',
      );
    }
    if (!_sameRequest(pending, next)) {
      throw ConnectionFailure(
        confirmed != null
            ? 'Your previous request was confirmed. Refresh My parking before making another change.'
            : 'Your previous request is still unconfirmed. Check My parking before making another change.',
      );
    }
    if (next['kind'] == 'change' && confirmed?.status == 'completed') {
      throw const ConnectionFailure(
        'This parking session has already ended. Refresh My parking.',
      );
    }
    if (confirmed == null &&
        _inFlight.containsKey(_requestKey(pending, owner))) {
      throw const ConnectionFailure(
        'The earlier request is still being processed. Check My parking before retrying.',
      );
    }
    return confirmed;
  }

  Future<ParkingSession> _send(
    Map<String, dynamic> request,
    String owner,
    Future<ParkingSession> Function() send,
  ) async {
    _checkUser(owner);
    await store?.write('session_request', request);
    _checkUser(owner);
    pendingRequest = request;
    ParkingSession session;
    try {
      final response = send();
      final key = _requestKey(request, owner);
      _inFlight[key] = response;
      void finished() {
        if (identical(_inFlight[key], response)) _inFlight.remove(key);
      }

      unawaited(
        response.then<void>(
          (_) => finished(),
          onError: (Object _, StackTrace _) => finished(),
        ),
      );
      session = await response.timeout(requestTimeout);
    } catch (error) {
      _checkUser(owner);
      if (store == null) rethrow;
      if (!isConnectionError(error)) {
        await store?.remove('session_request');
        pendingRequest = null;
        rethrow;
      }
      try {
        final recovered = await _recover(request, owner);
        if (recovered != null) return recovered;
      } catch (checkError) {
        if (!isConnectionError(checkError)) rethrow;
      }
      throw const ConnectionFailure(
        'We could not confirm the parking request. Your selection has been kept. Reconnect and check its status before retrying.',
      );
    }
    return _confirm(session, request, owner);
  }

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
    String parkingName = 'Parking stay',
  }) async {
    final owner = _userId();
    recoveredRequest = false;
    final request = <String, dynamic>{
      'kind': 'start',
      'parking_id': parkingId,
      'vehicle_id': vehicleId,
      'pickup_time': pickupTime.toUtc().toIso8601String(),
      'parking_name': parkingName,
    };
    if (store != null) {
      final confirmed = await _checkPending(request, owner);
      if (confirmed != null) return confirmed;
      final active = await repository.getActiveSession().timeout(
        requestTimeout,
      );
      _checkUser(owner);
      if (active != null) {
        await _remember(active, owner);
        throw const ConnectionFailure(
          'You already have an active session. Open My parking to check it.',
        );
      }
      if (pendingRequest == null) {
        final known = await repository
            .getMatchingSessions(
              parkingId: parkingId,
              vehicleId: vehicleId,
              pickupTime: pickupTime,
            )
            .timeout(requestTimeout);
        request['known_ids'] = known.map((session) => session.id).toList();
      } else {
        request['known_ids'] = pendingRequest!['known_ids'];
      }
    }
    return _send(
      request,
      owner,
      () => repository.createSession(
        parkingId: parkingId,
        pickupTime: pickupTime,
        vehicleId: vehicleId,
      ),
    );
  }

  Future<ParkingSession?> getActiveSession() async {
    if (currentUserId == null) return null;
    final owner = _userId();
    usingSavedSession = false;
    try {
      pendingRequest = await store?.read('session_request');
      if (pendingRequest != null) await _recover(pendingRequest!, owner);
      final session = await repository.getActiveSession().timeout(
        requestTimeout,
      );
      await _remember(session, owner);
      return session;
    } catch (error) {
      if (!isConnectionError(error) || store == null) rethrow;
      ParkingSession? session;
      if (local != null && !kIsWeb) {
        session = await local!.getActiveSession(owner);
      } else {
        final saved = await store?.read('active_session');
        if (saved?['session'] != null) {
          session = ParkingSession.fromMap(
            saved!['session'] as Map<String, dynamic>,
          );
        }
      }
      _checkUser(owner);
      if (session == null) {
        throw const ConnectionFailure(
          'No confirmed active session is saved. Connect to check your parking status.',
        );
      }
      if (session.userId != owner) {
        throw const AuthException('Sign in to continue.');
      }
      usingSavedSession = true;
      return session;
    }
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    String parkingName = 'Parking stay',
  }) async {
    final owner = _userId();
    recoveredRequest = false;
    final request = <String, dynamic>{
      'kind': 'change',
      'parking_name': parkingName,
      'session_id': sessionId,
      'pickup_time': pickupTime.toUtc().toIso8601String(),
    };
    if (store != null) {
      final confirmed = await _checkPending(request, owner);
      if (confirmed != null) return confirmed;
      final current = await repository
          .getSessionById(sessionId)
          .timeout(requestTimeout);
      _checkUser(owner);
      if (current == null || current.status != 'active') {
        throw const ConnectionFailure(
          'This session is no longer active. Refresh My parking.',
        );
      }
      final previous = pendingRequest?['previous_pickup_time'] as String?;
      if (previous != null &&
          !current.pickupTime.isAtSameMomentAs(DateTime.parse(previous))) {
        await store?.remove('session_request');
        pendingRequest = null;
        throw const ConnectionFailure(
          'The pickup time changed on the server. Refresh before choosing another time.',
        );
      }
      request['previous_pickup_time'] = current.pickupTime
          .toUtc()
          .toIso8601String();
    }
    return _send(
      request,
      owner,
      () => repository.updatePickupTime(
        sessionId: sessionId,
        pickupTime: pickupTime,
        previousPickupTime: request['previous_pickup_time'] == null
            ? null
            : DateTime.parse(request['previous_pickup_time'] as String),
      ),
    );
  }

  Future<ParkingSession> endParking({
    required String sessionId,
    String parkingName = 'Parking stay',
  }) async {
    final owner = _userId();
    recoveredRequest = false;
    historySaveFailed = false;
    final request = <String, dynamic>{
      'kind': 'end',
      'session_id': sessionId,
      'parking_name': parkingName,
    };
    if (store != null) {
      final confirmed = await _checkPending(request, owner);
      if (confirmed != null) return confirmed;
      final current = await repository
          .getSessionById(sessionId)
          .timeout(requestTimeout);
      _checkUser(owner);
      if (current?.status == 'completed') {
        return _confirm(current!, request, owner, recovered: true);
      }
      if (current == null || current.status != 'active') {
        throw const ConnectionFailure(
          'This session is no longer available. Refresh My parking.',
        );
      }
    }
    return _send(
      request,
      owner,
      () => repository.endSession(sessionId: sessionId),
    );
  }

  Future<bool> hasActiveSession() =>
      repository.hasActiveSession().timeout(requestTimeout);
}
