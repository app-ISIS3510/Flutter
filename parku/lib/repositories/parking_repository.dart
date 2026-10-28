import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking.dart';
import '../models/most_used_parking.dart';

class ParkingRepository {
  final SupabaseClient client;

  ParkingRepository(this.client);

  Future<List<MostUsedParking>> getMostUsedParkingLots() async {
    final response = await client
        .from('bq2_top_parking_completed_last_7_days')
        .select('parking_id,parking_name,completed_sessions')
        .order('completed_sessions', ascending: false)
        .order('parking_id', ascending: true)
        .limit(3);

    return response.map((row) => MostUsedParking.fromMap(row)).toList();
  }

  Future<List<Parking>> getParkingLots() async {
    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .order('name');

    return (response as List<dynamic>)
        .map((item) => Parking.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<Parking?> getParkingById(String id) async {
    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Parking.fromMap(response);
  }

  Future<List<Parking>> searchParkingLots(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    final response = await client
        .from('parking_lots_with_availability')
        .select()
        .or('name.ilike.%$trimmedQuery%,address.ilike.%$trimmedQuery%')
        .order('name');

    return (response as List<dynamic>)
        .map((item) => Parking.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
