import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking_session.dart';

class SessionRepository {
  final SupabaseClient client;

  SessionRepository(this.client);

  Future<ParkingSession> createSession({
    required String parkingId,
    required DateTime pickupTime,
    String vehicleType = 'car',
  }) async {
    final response = await client.rpc(
      'start_parking_session',
      params: {
        'p_parking_id': parkingId,
        'p_pickup_time':
            pickupTime.toUtc().toIso8601String(),
        'p_vehicle_type': vehicleType,
      },
    );

  return ParkingSession.fromMap(
    response as Map<String, dynamic>,
  );
}

  Future<ParkingSession?> getActiveSession() async {
    final response = await client
        .from('parking_sessions')
        .select()
        .eq('status', 'active')
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
        .update({
          'pickup_time': pickupTime.toUtc().toIso8601String(),
        })
        .eq('id', sessionId)
        .select()
        .single();

    return ParkingSession.fromMap(response);
  }

  Future<ParkingSession> endSession({
    required String sessionId,
  }) async {
    final response = await client
        .from('parking_sessions')
        .update({
          'status': 'completed',
          'ended_at': DateTime.now().toIso8601String(),
        })
        .eq('id', sessionId)
        .select()
        .single();

    return ParkingSession.fromMap(response);
  }

  Future<bool> hasActiveSession() async {
    final response = await client
        .from('parking_sessions')
        .select('id')
        .eq('status', 'active')
        .limit(1);

    return response.isNotEmpty;
  }
}