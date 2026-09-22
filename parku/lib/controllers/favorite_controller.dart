import '../models/parking.dart';
import '../services/favorite_service.dart';

class FavoriteController {
  final FavoriteService service;

  FavoriteController(this.service);

  Future<List<Parking>> loadFavorites() {
    return service.getFavorites();
  }

  Future<bool> isFavorite(String parkingId) {
    return service.isFavorite(parkingId);
  }

  Future<void> toggleFavorite(String parkingId) {
    return service.toggleFavorite(parkingId);
  }

  Future<void> removeFavorite(String parkingId) {
    return service.removeFavorite(parkingId);
  }
}