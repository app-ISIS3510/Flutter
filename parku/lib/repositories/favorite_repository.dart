import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/parking.dart';

class FavoriteRepository {
  final SupabaseClient client;

  FavoriteRepository(this.client);

  Future<List<Parking>> getFavorites() async {
    final response = await client
        .from('favorites')
        .select('parking_lots(*)')
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) {
          final parkingData =
              item['parking_lots'] as Map<String, dynamic>;

          return Parking.fromMap(parkingData);
        })
        .toList();
  }

  Future<bool> isFavorite(String parkingId) async {
    final response = await client
        .from('favorites')
        .select('id')
        .eq('parking_id', parkingId)
        .limit(1);

    return response.isNotEmpty;
  }

  Future<void> addFavorite(String parkingId) async {
    final alreadyFavorite = await isFavorite(parkingId);

    if (alreadyFavorite) {
      return;
    }

    await client.from('favorites').insert({
      'parking_id': parkingId,
    });
  }

  Future<void> removeFavorite(String parkingId) async {
    await client
        .from('favorites')
        .delete()
        .eq('parking_id', parkingId);
  }

  Future<void> toggleFavorite(String parkingId) async {
    final favorite = await isFavorite(parkingId);

    if (favorite) {
      await removeFavorite(parkingId);
    } else {
      await addFavorite(parkingId);
    }
  }
}