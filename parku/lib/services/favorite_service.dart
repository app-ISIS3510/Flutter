import '../models/parking.dart';
import '../repositories/favorite_repository.dart';

class FavoriteService {
  final FavoriteRepository repository;

  FavoriteService(this.repository);

  Future<List<Parking>> getFavorites() {
    return repository.getFavorites();
  }

  Future<bool> isFavorite(String parkingId) {
    return repository.isFavorite(parkingId);
  }

  Future<void> toggleFavorite(String parkingId) {
    return repository.toggleFavorite(parkingId);
  }

  Future<void> removeFavorite(String parkingId) {
    return repository.removeFavorite(parkingId);
  }
}