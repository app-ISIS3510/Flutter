import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';

class SessionRepository {
  final SupabaseClient client;

  SessionRepository(this.client);
  String get _userId =>
      client.auth.currentUser?.id ??
      (throw const AuthException('Sign in to continue.'));

  Future<ParkingSession> createSession({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) async {
    _userId;
    final response = await client.rpc(
      'start_parking_with_vehicle',
      params: {
        'p_parking_id': parkingId,
        'p_pickup_time': pickupTime.toUtc().toIso8601String(),
        'p_vehicle_id': vehicleId,
      },
    );

    return ParkingSession.fromMap(response as Map<String, dynamic>);
  }

  Future<ParkingSession?> getActiveSession() async {
    if (client.auth.currentUser == null) return null;
    final response = await client
        .from('parking_sessions')
        .select()
        .eq('status', 'active')
        .eq('user_id', _userId)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ParkingSession.fromMap(response);
  }

  Future<ParkingSession> updatePickupTime({
    required String sessionId,
    required DateTime pickupTime,
  }) async {
    final response = await client
        .from('parking_sessions')
        .update({'pickup_time': pickupTime.toUtc().toIso8601String()})
        .eq('id', sessionId)
        .eq('user_id', _userId)
        .select()
        .single();

    return ParkingSession.fromMap(response);
  }

  Future<ParkingSession> endSession({required String sessionId}) async {
    final response = await client
        .from('parking_sessions')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId)
        .eq('user_id', _userId)
        .select()
        .single();

    return ParkingSession.fromMap(response);
  }

  Future<bool> hasActiveSession() async {
    if (client.auth.currentUser == null) return false;
    final response = await client
        .from('parking_sessions')
        .select('id')
        .eq('status', 'active')
        .eq('user_id', _userId)
        .limit(1);

    return response.isNotEmpty;
  }
}
