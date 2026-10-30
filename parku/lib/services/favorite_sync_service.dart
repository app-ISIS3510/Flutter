import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/favorite_repository.dart';
import 'connectivity_service.dart';

class FavoriteSyncService extends ChangeNotifier {
  final FavoriteRepository repository;
  final ConnectivityService connectivity;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _timer;
  Future<void>? _running;
  bool _disposed = false;
  bool _started = false;

  FavoriteSyncService(this.repository, {ConnectivityService? connectivity})
    : connectivity = connectivity ?? ConnectivityService();

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _connectionSubscription = connectivity.onNetworkChanged.listen((connected) {
      if (connected) unawaited(flush());
    }, onError: (Object _) {});
    _authSubscription = repository.client.auth.onAuthStateChange.listen(
      (_) => unawaited(flush()),
      onError: (Object _) {},
    );
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(flush()),
    );
    unawaited(flush());
  }

  Future<void> flush() {
    if (_disposed) return Future.value();
    return _running ??= _flush().whenComplete(() => _running = null);
  }

  Future<void> _flush() async {
    try {
      final userId = repository.client.auth.currentUser?.id;
      if (userId == null) return;
      try {
        if (!await connectivity.hasNetworkConnection().timeout(
          const Duration(seconds: 3),
        )) {
          return;
        }
      } catch (_) {}
      if (_disposed) return;
      final before =
          (await repository.localDataSource.read(userId))?.pendingCount ?? 0;
      if (before == 0) return;
      await repository.syncPending();
      if (_disposed || repository.client.auth.currentUser?.id != userId) return;
      final after =
          (await repository.localDataSource.read(userId))?.pendingCount ?? 0;
      if (before != after && !_disposed) notifyListeners();
    } catch (error, stackTrace) {
      developer.log(
        'Could not synchronize saved favorites',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _connectionSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
