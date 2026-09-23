import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient client;

  DashboardRepository(this.client);

  Future<List<Map<String, dynamic>>> getBq1() async {
    final response = await client
        .from('bq1_parking_starts_last_7_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBq2() async {
    final response = await client
        .from('bq2_top_parking_completed_last_7_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBq3() async {
    final response = await client
        .from('bq3_parking_flow_abandonment_last_7_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBq4() async {
    final response = await client
        .from('bq4_favorite_additions_last_7_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBq5() async {
    final response = await client
        .from('bq5_action_usage_last_7_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getBq6() async {
    final response = await client
        .from('bq6_top_parking_by_2h_slot_last_30_days')
        .select();

    return List<Map<String, dynamic>>.from(response);
  }
}