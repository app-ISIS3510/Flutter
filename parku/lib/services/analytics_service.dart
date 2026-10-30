import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/analytics_repository.dart';
import 'connectivity_service.dart';
import 'device_context_service.dart';

class AnalyticsService {
  final AnalyticsRepository repository;
  final ConnectivityService connectivityService;
  final DeviceContextService deviceContextService;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _retryTimer;
  bool _started = false;
  bool _disposed = false;
  Future<void>? _syncFuture;

  AnalyticsService(
    this.repository, {
    ConnectivityService? connectivityService,
    DeviceContextService? deviceContextService,
  }) : connectivityService = connectivityService ?? ConnectivityService(),
       deviceContextService = deviceContextService ?? DeviceContextService();

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _connectivitySubscription = connectivityService.onNetworkChanged.listen(
      (hasNetwork) {
        if (hasNetwork) unawaited(flushPending());
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Could not observe analytics connectivity',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    _authSubscription = repository.client.auth.onAuthStateChange.listen(
      (_) => unawaited(flushPending()),
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Could not observe analytics authentication',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(flushPending()),
    );
    unawaited(flushPending());
  }

  Future<void> flushPending() {
    if (_disposed) return Future.value();
    return _syncFuture ??= _sync().whenComplete(() => _syncFuture = null);
  }

  Future<void> _sync() async {
    try {
      if (repository.client.auth.currentUser == null) return;
      try {
        final hasNetwork = await connectivityService
            .hasNetworkConnection()
            .timeout(const Duration(seconds: 3));
        if (!hasNetwork || _disposed) return;
      } catch (_) {
        // An unavailable connectivity check must not block a real send attempt.
      }
      if (!_disposed) await repository.flushPending();
    } catch (error, stackTrace) {
      developer.log(
        'Could not synchronize pending analytics',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> track({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = repository.client.auth.currentUser?.id;
    if (userId == null) return;
    final occurredAt = DateTime.now().toUtc();
    final deviceContext = await deviceContextService.read();
    // Device enrichment must not reassign an event after switching accounts.
    if (repository.client.auth.currentUser?.id != userId) return;
    await repository.trackEvent(
      eventType: eventType,
      screen: screen,
      parkingId: parkingId,
      metadata: {...?metadata, ...deviceContext, 'platform': 'flutter'},
      occurredAt: occurredAt,
    );
    if (!_disposed) unawaited(flushPending());
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
  }
}
