import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepository {
  final SupabaseClient client;

  AnalyticsRepository(this.client);

  Future<void> trackEvent({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
  }) async {
    await client.from('analytics_events').insert({
      'event_type': eventType,
      'screen': screen,
      'parking_id': parkingId,
      'metadata': metadata ?? {},
    });
  }
}