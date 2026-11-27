import 'dart:collection';

import '../../models/parking.dart';
import '../../state/favorite_list_state.dart';

class FavoriteMemoryCache {
  final HashMap<String, FavoriteListState> _snapshots = HashMap();

  String? _activeUserId;
  int _generation = 0;

  int get generation => _generation;

  void selectUser(String userId) {
    if (_activeUserId == userId) return;

    _snapshots.clear();
    _activeUserId = userId;
    _generation++;
  }

  FavoriteListState? read(String userId) {
    selectUser(userId);
    return _snapshots[userId];
  }

  void write(
    String userId,
    FavoriteListState snapshot, {
    required int expectedGeneration,
  }) {
    if (_activeUserId != userId || _generation != expectedGeneration) {
      return;
    }

    _snapshots[userId] = FavoriteListState(
      favorites: List<Parking>.unmodifiable(snapshot.favorites),
      isFromCache: true,
      updatedAt: snapshot.updatedAt,
      pendingCount: snapshot.pendingCount,
    );
  }

  void invalidate(String userId) {
    if (_activeUserId != userId) return;

    _snapshots.remove(userId);
    _generation++;
  }

  void clear() {
    _snapshots.clear();
    _activeUserId = null;
    _generation++;
  }
}
