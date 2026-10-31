import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';
import '../services/connection_failure.dart';
import '../data/local/session_local_data_source.dart';
import '../utils/async_operations.dart';

class SessionRepository {
  final SupabaseClient client;
  final SessionLocalDataSource localDataSource;
  final _operations = AsyncSerialExecutor();
  final _activeReads = SingleFlight<String, ParkingSession?>();
  final _mutations = SingleFlight<String, ParkingSession>();
  int _readEpoch = 0;
  bool lastReadFromCache = false;

  SessionRepository(this.client, {SessionLocalDataSource? localDataSource})
    : localDataSource = localDataSource ?? SessionLocalDataSource();
  String get _userId =>
      client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to continue.'));

  void _checkUser(String userId) {
    if (client.auth.currentUser?.id != userId) {
      throw const AuthException('The signed-in account changed.');
    }
  }

  Future<ParkingSession> _mutation(
    String key,
    Future<ParkingSession> Function() operation,
  ) {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return Future.error(const AuthException('Sign in to continue.'));
    }
    return _mutations.run('$userId:$key', () {
      _readEpoch++;
      return _operations.run(() {
        _checkUser(userId);
        return operation();
      });
    });
  }

  Future<ParkingSession> _confirmed(
    String userId,
    Map<String, dynamic> row,
  ) async {
    _checkUser(userId);
    final session = ParkingSession.fromMap(row);
    if (session.userId != null && session.userId != userId) {
      throw const AuthException('Session belongs to another account.');
    }
    try {
      await localDataSource.saveConfirmed(userId, session);
    } catch (error, stackTrace) {
      developer.log(
        'Could not cache a confirmed session',
        error: error,
        stackTrace: stackTrace,
      );
    }
    _checkUser(userId);
    return session;
  }

  Future<ParkingSession> createSession({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) => _mutation(
    'start:$parkingId:$vehicleId:${pickupTime.toUtc().toIso8601String()}',
    () => _createSession(
      parkingId: parkingId,
      pickupTime: pickupTime,
      vehicleId: vehicleId,
    ),
  );

  Future<ParkingSession> _createSession({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) async {
    final userId = _userId;
    final response = await client
        .rpc(
          'start_parking_with_vehicle',
          params: {
            'p_parking_id': parkingId,
            'p_pickup_time': pickupTime.toUtc().toIso8601String(),
            'p_vehicle_id': vehicleId,
          },
        )
        .timeout(const Duration(seconds: 15));

    _checkUser(userId);
    return _confirmed(userId, response as Map<String, dynamic>);
  }

  Future<ParkingSession?> getActiveSession() {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return Future.value(null);
    return _activeReads.run(
      '$userId:$_readEpoch',
      () => _operations.run(() {
        _checkUser(userId);
        return _fetchActiveSession();
      }),
    );
  }

  Future<ParkingSession?> _fetchActiveSession() async {
    final userId = _userId;
    lastReadFromCache = false;
    try {
      final response = await client
          .from('parking_sessions')
          .select()
          .eq('status', 'active')
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      _checkUser(userId);

      if (response == null) {
        try {
          await localDataSource.saveNoActiveSession(userId);
        } catch (error, stackTrace) {
          developer.log(
            'Could not cache the empty active-session snapshot',
            error: error,
            stackTrace: stackTrace,
          );
        }
        _checkUser(userId);
        return null;
      }

      return await _confirmed(userId, response);
    } catch (error, stackTrace) {
      _checkUser(userId);
      developer.log(
        'Could not refresh the active session',
        error: error,
        stackTrace: stackTrace,
      );
      try {
        final cached = await localDataSource.readActive(userId);
        _checkUser(userId);
        if (cached.hasSnapshot) {
          lastReadFromCache = true;
          return cached.session;
        }
      } catch (_) {
        _checkUser(userId);
      }
      rethrow;
    }
  }

    Future<ParkingSession> updatePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    DateTime? previousPickupTime,
  }) {
    final nextTime = pickupTime.toUtc().toIso8601String();
    final previousTime =
        previousPickupTime?.toUtc().toIso8601String() ?? 'any';

    return _mutation(
      'pickup:$sessionId:$nextTime:$previousTime',
      () => _updatePickupTime(
        sessionId: sessionId,
        pickupTime: pickupTime,
        previousPickupTime: previousPickupTime,
      ),
    );
  }

  Future<ParkingSession> _updatePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    DateTime? previousPickupTime,
  }) async {
    final userId = _userId;

    var query = client
        .from('parking_sessions')
        .update({
          'pickup_time': pickupTime.toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('user_id', userId)
        .eq('status', 'active');

    if (previousPickupTime != null) {
      query = query.eq(
        'pickup_time',
        previousPickupTime.toUtc().toIso8601String(),
      );
    }

    final response = await query
        .select()
        .timeout(const Duration(seconds: 15));

    _checkUser(userId);

    if (response.isEmpty) {
      final session = await _fetchSessionById(
        sessionId,
        userId,
      );

      _checkUser(userId);

      if (session != null &&
          session.status == 'active' &&
          session.pickupTime.isAtSameMomentAs(pickupTime)) {
        return session;
      }

      throw const ConnectionFailure(
        'This parking session changed. '
        'Refresh My parking before trying again.',
      );
    }

    return _confirmed(userId, response.single);
  }

  Future<ParkingSession> endSession({
    required String sessionId,
  }) {
    return _mutation(
      'end:$sessionId',
      () => _endSession(sessionId: sessionId),
    );
  }

  Future<ParkingSession> _endSession({
    required String sessionId,
  }) async {
    final userId = _userId;

    final response = await client
        .from('parking_sessions')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('user_id', userId)
        .eq('status', 'active')
        .select()
        .timeout(const Duration(seconds: 15));

    _checkUser(userId);

    if (response.isEmpty) {
      final session = await _fetchSessionById(
        sessionId,
        userId,
      );

      _checkUser(userId);

      if (session != null && session.status == 'completed') {
        return session;
      }

      throw const ConnectionFailure(
        'This parking session changed. '
        'Refresh My parking before trying again.',
      );
    }

    return _confirmed(userId, response.single);
  }

  Future<ParkingSession?> getSessionById(String id) async {
    final userId = _userId;

    return _operations.run(
      () => _fetchSessionById(id, userId),
    );
  }

  // Calling _operations again here would make the queue wait on itself.
  Future<ParkingSession?> _fetchSessionById(
    String id,
    String userId,
  ) async {
    _checkUser(userId);

    final row = await client
        .from('parking_sessions')
        .select()
        .eq('id', id)
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 8));

    _checkUser(userId);

    if (row == null) return null;

    return _confirmed(userId, row);
  }

  Future<List<ParkingSession>> getMatchingSessions({
    required String parkingId,
    required String vehicleId,
    required DateTime pickupTime,
  }) async {
    final userId = _userId;

    return _operations.run(() async {
      _checkUser(userId);

      final rows = await client
          .from('parking_sessions')
          .select()
          .eq('user_id', userId)
          .eq('parking_id', parkingId)
          .eq('vehicle_id', vehicleId)
          .eq(
            'pickup_time',
            pickupTime.toUtc().toIso8601String(),
          )
          .order('started_at', ascending: false)
          .timeout(const Duration(seconds: 8));

      _checkUser(userId);

      final sessions = <ParkingSession>[];

      for (final row in rows) {
        sessions.add(await _confirmed(userId, row));
      }

      return sessions;
    });
  }

  Future<bool> hasActiveSession() async {
    return await getActiveSession() != null;
  }
}
