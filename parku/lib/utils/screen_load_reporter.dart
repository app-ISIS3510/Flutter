import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import '../controllers/analytics_controller.dart';
import '../models/analytics_measurements.dart';

class ScreenLoadReporter with WidgetsBindingObserver {
  final AnalyticsController? analytics;
  final String screen;
  final String? parkingId;
  final String? _userId;
  final ScreenLoadMeasurement _measurement;
  bool _scheduled = false;
  bool _cancelled = false;
  bool _completed = false;

  ScreenLoadReporter(
    this.analytics,
    this.screen, {
    this.parkingId,
    String trigger = 'navigation',
  }) : _userId = analytics?.currentUserId,
       _measurement = ScreenLoadMeasurement(trigger: trigger) {
    if (analytics != null) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      cancel();
    }
  }

  void presented(
    BuildContext context, {
    required String source,
    bool failed = false,
  }) {
    if (_scheduled || _cancelled || _completed || analytics == null) return;
    final route = ModalRoute.of(context);
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_cancelled ||
          !context.mounted ||
          analytics!.currentUserId != _userId) {
        return;
      }
      if (route?.isCurrent == false) {
        cancel();
        return;
      }
      final data = _measurement.finish(source: source, failed: failed);
      if (data == null) return;
      _completed = true;
      WidgetsBinding.instance.removeObserver(this);
      // The stopwatch stops before reading device metadata or queueing SQLite.
      unawaited(
        analytics!
            .track(
              eventType: failed
                  ? 'screen_load_failed'
                  : 'screen_load_completed',
              screen: screen,
              parkingId: parkingId,
              metadata: data,
            )
            .catchError((Object error, StackTrace stack) {
              developer.log(
                'Could not queue screen load measurement',
                error: error,
                stackTrace: stack,
              );
            }),
      );
    });
  }

  void cancel() {
    _cancelled = true;
    _measurement.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
