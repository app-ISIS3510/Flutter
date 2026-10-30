import '../models/parking.dart';
import '../services/favorite_service.dart';
import '../state/favorite_list_state.dart';

class FavoriteController {
  final FavoriteService service;

  FavoriteController(this.service);

  Future<List<Parking>> loadFavorites() {
    return service.getFavorites();
  }

  Future<FavoriteListState> loadFavoriteSnapshot() =>
      service.getFavoriteSnapshot();

  Future<bool> isFavorite(String parkingId) {
    return service.isFavorite(parkingId);
  }

  Future<bool> toggleFavorite(String parkingId) {
    return service.toggleFavorite(parkingId);
  }

  Future<void> removeFavorite(String parkingId) {
    return service.removeFavorite(parkingId);
  }
}
