import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRepository {
  final SupabaseClient client;

  AnalyticsRepository(this.client);

  String? get userId => client.auth.currentUser?.id;

  Future<void> savePickupChoice(Map<String, dynamic> event) async {
    if (userId != event['user_id']) {
      throw const AuthException('The signed-in account has changed.');
    }
    await client
        .from('analytics_events')
        .upsert(event, onConflict: 'id', ignoreDuplicates: true);
  }

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
