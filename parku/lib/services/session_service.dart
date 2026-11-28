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
import 'connectivity_service.dart';
import 'pickup_analytics_service.dart';

class NoSavedActiveSession extends ConnectionFailure {
  const NoSavedActiveSession()
    : super(
        'No confirmed active session is saved. Connect to check your parking status.',
      );
}

typedef PendingParkingStart = ({
  String parkingId,
  String vehicleId,
  DateTime pickupTime,
  String? parkingName,
  String? vehicleType,
  String? vehiclePlate,
  bool canEdit,
});

class SessionService {
  final SessionRepository repository;
  final SessionHistoryRepository historyRepository;
  final UserLocalStore? store;
  final PersonalDataRepository? local;
  final PickupAnalyticsService? pickupAnalytics;
  final Duration requestTimeout;
  final Future<bool?> Function() checkConnection;
  final DateTime Function() currentTime;
  bool _syncing = false;
  bool _editingQueuedStart = false;
  bool historySaveFailed = false;
  bool localSaveFailed = false;
  bool usingSavedSession = false;
  bool recoveredRequest = false;
  Map<String, dynamic>? pendingRequest;
  final _inFlight = <String, Future<ParkingSession>>{};
  int _stateVersion = 0;

  SessionService(
    this.repository, {
    SessionHistoryRepository? historyRepository,
    this.store,
    this.local,
    this.pickupAnalytics,
    this.requestTimeout = const Duration(seconds: 8),
    Future<bool?> Function()? checkConnection,
    DateTime Function()? currentTime,
  }) : historyRepository =
           historyRepository ?? SessionHistoryRepository(repository.client),
       checkConnection =
           checkConnection ?? ConnectivityService().connectionStatus,
       currentTime = currentTime ?? DateTime.now;

  String? get currentUserId => repository.client.auth.currentUser?.id;
  bool get historyAvailable => historyRepository.isAvailable;
  PendingParkingStart? get pendingStart {
    final request = pendingRequest;
    if (request == null || request['kind'] != 'start') return null;
    final parkingId = request['parking_id'] as String?;
    final vehicleId = request['vehicle_id'] as String?;
    final pickupTime = DateTime.tryParse(
      request['pickup_time'] as String? ?? '',
    );
    if (parkingId == null || vehicleId == null || pickupTime == null) {
      return null;
    }
    return (
      parkingId: parkingId,
      vehicleId: vehicleId,
      pickupTime: pickupTime,
      parkingName: request['parking_name'] as String?,
      vehicleType: request['vehicle_type'] as String?,
      vehiclePlate: request['vehicle_plate'] as String?,
      canEdit: request['queued'] == true,
    );
  }

  String? get notice {
    if (pendingRequest?['kind'] == 'end') {
      return 'Your end request is saved on this device. Parking remains active until the server confirms it.';
    }
    if (pendingRequest != null) {
      return 'Your parking request is saved on this device. It will be checked when you reconnect. It is not confirmed yet.';
    }
    if (usingSavedSession) {
      return 'Showing your last confirmed parking data. Changes are saved here until you reconnect.';
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
    _stateVersion++;
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

  /// Edits or cancels a start that has never been sent to the server.
  Future<void> editQueuedStart(
    PendingParkingStart expected, {
    DateTime? pickupTime,
  }) async {
    if (_syncing || _editingQueuedStart) {
      throw const ConnectionFailure(
        'The parking request is being checked. Try again in a moment.',
      );
    }
    final owner = _userId();
    _editingQueuedStart = true;
    try {
      await restorePendingRequest();
      _checkUser(owner);
      if (store == null || pendingStart != expected || !expected.canEdit) {
        throw const ConnectionFailure(
          'The parking request changed. Check My parking before making changes.',
        );
      }
      if (pickupTime == null) {
        await store!.remove('session_request');
        _checkUser(owner);
        pendingRequest = null;
        return;
      }
      if (!pickupTime.isAfter(currentTime())) {
        throw const ConnectionFailure('Choose a pickup time in the future.');
      }
      final updated = {
        ...pendingRequest!,
        'pickup_time': pickupTime.toUtc().toIso8601String(),
      };
      await store!.write('session_request', updated);
      _checkUser(owner);
      pendingRequest = updated;
    } finally {
      _editingQueuedStart = false;
    }
  }

  Future<Never> _queueRequest(
    Map<String, dynamic> request,
    String owner, {
    bool sent = false,
  }) async {
    if (store == null) {
      throw const ConnectionFailure('Connect to send your parking request.');
    }
    await restorePendingRequest();
    _checkUser(owner);
    final previous = pendingRequest;
    final sameSession =
        previous?['session_id'] != null &&
        previous?['session_id'] == request['session_id'];
    final canReplace =
        previous?['queued'] == true &&
        sameSession &&
        (request['kind'] == 'end' || previous?['kind'] == 'change');
    if (previous != null && !_sameRequest(previous, request) && !canReplace) {
      throw const ConnectionFailure(
        'Another parking request is pending. Reconnect to confirm it first.',
      );
    }
    final saved = previous != null && _sameRequest(previous, request)
        ? previous
        : {
            ...request,
            if (canReplace && previous?['previous_pickup_time'] != null)
              'previous_pickup_time': previous!['previous_pickup_time'],
            'queued': !sent,
          };
    await store!.write('session_request', saved);
    _checkUser(owner);
    pendingRequest = saved;
    throw QueuedChange(
      request['kind'] == 'end'
          ? 'Your request is saved on this device and will be sent when you reconnect. Parking remains active until the server confirms it.'
          : 'Your request is saved on this device. It will be sent when you reconnect. It is not confirmed yet.',
    );
  }

  Future<bool> syncPendingRequest() async {
    if (store == null || _syncing || _editingQueuedStart) return false;
    _syncing = true;
    final owner = _userId();
    try {
      if (await checkConnection() == false) return false;
      _checkUser(owner);
      await restorePendingRequest();
      _checkUser(owner);
      final request = pendingRequest;
      if (request == null) return false;
      if (_inFlight.containsKey(_requestKey(request, owner))) return false;
      if (request['queued'] != true) {
        if (await _recover(request, owner) != null) return true;
      }
      final pickup = DateTime.tryParse(request['pickup_time'] as String? ?? '');
      if (pickup != null && !pickup.isAfter(currentTime())) {
        await store!.remove('session_request');
        _checkUser(owner);
        pendingRequest = null;
        throw const ConnectionFailure(
          'Your saved pickup time has passed. Choose a new time before sending the request.',
        );
      }
      switch (request['kind']) {
        case 'start':
          await startParking(
            parkingId: request['parking_id'] as String,
            vehicleId: request['vehicle_id'] as String,
            pickupTime: pickup!,
            parkingName: request['parking_name'] as String? ?? 'Parking stay',
            vehicleType: request['vehicle_type'] as String?,
            vehiclePlate: request['vehicle_plate'] as String?,
            suggestedPickupTime: DateTime.tryParse(
              request['suggested_pickup_time'] as String? ?? '',
            ),
            replaying: true,
          );
        case 'change':
          await changePickupTime(
            sessionId: request['session_id'] as String,
            pickupTime: pickup!,
            parkingName: request['parking_name'] as String? ?? 'Parking stay',
            replaying: true,
          );
        case 'end':
          await endParking(
            sessionId: request['session_id'] as String,
            parkingName: request['parking_name'] as String? ?? 'Parking stay',
            replaying: true,
          );
        default:
          throw const ConnectionFailure(
            'This saved parking request needs to be reviewed.',
          );
      }
      return true;
    } on QueuedChange {
      return false;
    } catch (error) {
      if (isConnectionError(error)) return false;
      rethrow;
    } finally {
      _syncing = false;
    }
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

  Future<ParkingSummary> buildParkingSummary(
    ParkingSession session, {
    required String parkingName,
  }) async {
    final owner = _userId();

    _checkUser(owner);

    Parking? parking;

    try {
      parking = await getSavedParking(session.parkingId);
    } catch (_) {
      // Parking details may not be available locally.
    }

    _checkUser(owner);

    return ParkingSummary.fromSession(
      session,
      parkingName: parking?.name ?? parkingName,
      parkingAddress: parking?.address,
      pricePerMinute: parking?.pricePerMinute,
    );
  }

  Future<void> _saveSummary(ParkingSession session, String name) async {
    historySaveFailed = false;

    if (!historyAvailable) return;

    try {
      final summary = await buildParkingSummary(session, parkingName: name);

      await historyRepository.saveSummary(summary);
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
    _stateVersion++;
    await _remember(session, owner);
    if (request['kind'] == 'start') {
      await pickupAnalytics?.saveChoice(session, request);
      _checkUser(owner);
    }
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
    if (pending['queued'] == true) {
      if (!_sameRequest(pending, next)) {
        throw const ConnectionFailure(
          'Another parking request is pending. Reconnect to confirm it first.',
        );
      }
      return null;
    }
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
    request = {...request, 'queued': false};
    await store?.write('session_request', request);
    _checkUser(owner);
    pendingRequest = request;
    if (_inFlight.containsKey(_requestKey(request, owner))) {
      throw const ConnectionFailure(
        'The earlier parking request is still being processed.',
      );
    }
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
      return _queueRequest(request, owner, sent: true);
    }
    return _confirm(session, request, owner);
  }

  bool get lastReadFromCache => repository.lastReadFromCache;

  Future<ParkingSession> startParking({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
    String parkingName = 'Parking stay',
    String? vehicleType,
    String? vehiclePlate,
    DateTime? suggestedPickupTime,
    bool replaying = false,
  }) async {
    final owner = _userId();
    _stateVersion++;
    recoveredRequest = false;
    final request = <String, dynamic>{
      'kind': 'start',
      'parking_id': parkingId,
      'vehicle_id': vehicleId,
      'pickup_time': pickupTime.toUtc().toIso8601String(),
      'parking_name': parkingName,
      'vehicle_type': ?vehicleType,
      'vehicle_plate': ?vehiclePlate,
      if (suggestedPickupTime != null)
        'suggested_pickup_time': suggestedPickupTime.toUtc().toIso8601String(),
    };
    if (await checkConnection() == false) {
      if (!replaying) return _queueRequest(request, owner);
      throw const QueuedChange(
        'Your parking request is still saved on this device.',
      );
    }
    try {
      if (store != null) {
        final confirmed = await _checkPending(request, owner);
        if (confirmed != null) return confirmed;
        final active = await repository.getActiveSession().timeout(
          requestTimeout,
        );
        _checkUser(owner);
        if (active != null) {
          await _remember(active, owner);
          if (replaying) {
            await store?.remove('session_request');
            _checkUser(owner);
            pendingRequest = null;
          }
          throw const ConnectionFailure(
            'You already have an active session. Open My parking to check it.',
          );
        }
        if (pendingRequest == null || pendingRequest?['queued'] == true) {
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
          if (pendingRequest!.containsKey('suggested_pickup_time')) {
            request['suggested_pickup_time'] =
                pendingRequest!['suggested_pickup_time'];
          } else {
            request.remove('suggested_pickup_time');
          }
        }
      }
      return await _send(
        request,
        owner,
        () => repository.createSession(
          parkingId: parkingId,
          pickupTime: pickupTime,
          vehicleId: vehicleId,
        ),
      );
    } catch (error) {
      if (!replaying && store != null && isConnectionError(error)) {
        return _queueRequest(request, owner);
      }
      rethrow;
    }
  }

  Future<ParkingSession?> getActiveSession() async {
    if (currentUserId == null) return null;
    final owner = _userId();
    usingSavedSession = false;
    try {
      await restorePendingRequest();
      if (await checkConnection() == false) {
        return await _savedActiveSession(owner);
      }
      if (pendingRequest != null) await syncPendingRequest();
      final version = _stateVersion;
      final session = await repository.getActiveSession().timeout(
        requestTimeout,
      );
      _checkUser(owner);
      if (version == _stateVersion) await _remember(session, owner);
      return session;
    } catch (error) {
      if ((!isConnectionError(error) && error is! QueuedChange) ||
          store == null) {
        rethrow;
      }
      return await _savedActiveSession(owner);
    }
  }

  Future<ParkingSession?> _savedActiveSession(String owner) async {
    final session = await getSavedActiveSession();
    _checkUser(owner);
    if (session == null && pendingRequest?['kind'] != 'start') {
      throw const NoSavedActiveSession();
    }
    usingSavedSession = true;
    return session;
  }

  /// Read the saved session without contacting the server.
  Future<ParkingSession?> getSavedActiveSession() async {
    if (currentUserId == null) return null;
    final owner = _userId();
    ParkingSession? session;
    if (local != null && !kIsWeb) {
      session = await local!.getActiveSession(owner);
    } else {
      final saved = await store?.read('active_session');
      if (saved?['session'] != null) {
        session = ParkingSession.fromMap(
          saved!['session'] as Map<String, dynamic>,
          isFromCache: true,
        );
      }
    }
    _checkUser(owner);
    if (session?.userId != null && session!.userId != owner) {
      throw const AuthException('Sign in to continue.');
    }
    return session;
  }

  Future<ParkingSession> changePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    String parkingName = 'Parking stay',
    bool replaying = false,
  }) async {
    final owner = _userId();
    _stateVersion++;
    recoveredRequest = false;
    final request = <String, dynamic>{
      'kind': 'change',
      'parking_name': parkingName,
      'session_id': sessionId,
      'pickup_time': pickupTime.toUtc().toIso8601String(),
    };
    final savedSession = await getSavedActiveSession();
    _checkUser(owner);
    if (savedSession?.id == sessionId) {
      request['previous_pickup_time'] = savedSession!.pickupTime
          .toUtc()
          .toIso8601String();
    }
    if (await checkConnection() == false) {
      if (!replaying) {
        return _queueRequest(request, owner);
      }
      throw const QueuedChange(
        'Your parking request is still saved on this device.',
      );
    }
    try {
      if (store != null) {
        final confirmed = await _checkPending(request, owner);
        if (confirmed != null) return confirmed;
        final current = await repository
            .getSessionById(sessionId)
            .timeout(requestTimeout);
        _checkUser(owner);
        if (current == null || current.status != 'active') {
          if (replaying) {
            await store?.remove('session_request');
            _checkUser(owner);
            pendingRequest = null;
          }
          throw const ConnectionFailure(
            'This session is no longer active. Refresh My parking.',
          );
        }
        final previous =
            (pendingRequest?['previous_pickup_time'] ??
                    request['previous_pickup_time'])
                as String?;
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
      return await _send(
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
    } catch (error) {
      if (!replaying && store != null && isConnectionError(error)) {
        return _queueRequest(request, owner);
      }
      rethrow;
    }
  }

  Future<ParkingSession> endParking({
    required String sessionId,
    String parkingName = 'Parking stay',
    bool replaying = false,
  }) async {
    final owner = _userId();
    _stateVersion++;
    recoveredRequest = false;
    historySaveFailed = false;
    final request = <String, dynamic>{
      'kind': 'end',
      'session_id': sessionId,
      'parking_name': parkingName,
    };
    if (await checkConnection() == false) {
      if (!replaying) return _queueRequest(request, owner);
      throw const QueuedChange(
        'Your parking request is still saved on this device.',
      );
    }
    try {
      if (store != null) {
        final confirmed = await _checkPending(request, owner);
        if (confirmed != null) return confirmed;
        final current = await repository
            .getSessionById(sessionId)
            .timeout(requestTimeout);
        _checkUser(owner);
        if (current?.status == 'completed') {
          return await _confirm(current!, request, owner, recovered: true);
        }
        if (current == null || current.status != 'active') {
          if (replaying) {
            await store?.remove('session_request');
            _checkUser(owner);
            pendingRequest = null;
          }
          throw const ConnectionFailure(
            'This session is no longer available. Refresh My parking.',
          );
        }
      }
      return await _send(
        request,
        owner,
        () => repository.endSession(sessionId: sessionId),
      );
    } catch (error) {
      if (!replaying && store != null && isConnectionError(error)) {
        return _queueRequest(request, owner);
      }
      rethrow;
    }
  }

  Future<bool> hasActiveSession() =>
      repository.hasActiveSession().timeout(requestTimeout);
}
