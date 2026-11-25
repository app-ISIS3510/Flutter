import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../services/analytics_service.dart';

class ScreenTimeRoute<T> extends MaterialPageRoute<T> {
  final String screen;

  ScreenTimeRoute({required this.screen, required super.builder});
}

class ScreenTimeObserver extends NavigatorObserver {
  final Duration Function() _elapsed;
  final DateTime Function() _now;
  AnalyticsService? _analytics;
  String? _userId;
  Route<dynamic>? _topRoute;
  String _homeScreen = 'map';
  bool _foreground = false;
  String? _visibleScreen;
  Duration _startedAt = Duration.zero;
  Timer? _timer;

  ScreenTimeObserver({Duration Function()? elapsed, DateTime Function()? now})
    : _elapsed = elapsed ?? _stopwatchTime(),
      _now = now ?? DateTime.now;

  static Duration Function() _stopwatchTime() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  void start(AnalyticsService analytics) {
    final previous = _analytics;
    if (previous != null) stop(previous);
    _analytics = analytics;
    _userId = analytics.repository.userId;
    _homeScreen = 'map';
    setLifecycleState(WidgetsBinding.instance.lifecycleState);
  }

  void stop(AnalyticsService analytics) {
    if (_analytics != analytics) return;
    setLifecycleState(null);
    _analytics = null;
    _userId = null;
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _topRoute = topRoute;
    _updateScreen();
  }

  void setHomeScreen(String screen) {
    _homeScreen = screen;
    _updateScreen();
  }

  void setLifecycleState(AppLifecycleState? state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateScreen();
  }

  void _updateScreen() {
    final route = _topRoute;
    String? screen;
    if (_foreground && route is PageRoute) {
      if (route.isFirst) {
        screen = _homeScreen;
      } else if (route is ScreenTimeRoute) {
        screen = route.screen;
      }
    }
    if (screen == _visibleScreen) return;

    unawaited(saveTime());
    _visibleScreen = screen;
    _startedAt = _elapsed();
    _timer?.cancel();
    _timer = screen == null
        ? null
        : Timer.periodic(const Duration(minutes: 1), (_) {
            unawaited(saveTime());
          });
  }

  Future<void> saveTime() async {
    final screen = _visibleScreen;
    final analytics = _analytics;
    if (screen == null ||
        analytics == null ||
        _userId == null ||
        _userId != analytics.repository.userId) {
      return;
    }

    final end = _elapsed();
    final durationMs = (end - _startedAt).inMilliseconds;
    if (durationMs <= 0) return;
    _startedAt = end;

    try {
      await analytics.track(
        eventType: 'screen_time_spent',
        screen: screen,
        metadata: {'duration_ms': durationMs},
        occurredAt: _now(),
        includeDeviceContext: false,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Could not save screen time',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
