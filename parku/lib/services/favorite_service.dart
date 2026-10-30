import '../models/parking.dart';
import '../repositories/favorite_repository.dart';
import '../state/favorite_list_state.dart';

class FavoriteService {
  final FavoriteRepository repository;

  FavoriteService(this.repository);

  Future<List<Parking>> getFavorites() {
    return repository.getFavorites();
  }

  Future<FavoriteListState> getFavoriteSnapshot() =>
      repository.getFavoriteSnapshot();

  Future<bool> isFavorite(String parkingId) {
    return repository.isFavorite(parkingId);
  }

  Future<bool> toggleFavorite(String parkingId) {
    return repository.toggleFavorite(parkingId);
  }

  Future<void> removeFavorite(String parkingId) {
    return repository.removeFavorite(parkingId);
  }
}
