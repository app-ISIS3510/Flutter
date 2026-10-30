import '../models/parking.dart';

class FavoriteListState {
  final List<Parking> favorites;
  final bool isFromCache;
  final DateTime? updatedAt;
  final int pendingCount;

  const FavoriteListState({
    required this.favorites,
    this.isFromCache = false,
    this.updatedAt,
    this.pendingCount = 0,
  });
}
