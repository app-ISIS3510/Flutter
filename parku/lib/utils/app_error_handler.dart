import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../widgets/unexpected_error_view.dart';
import '../widgets/user_error_notice.dart';
import 'error_messages.dart';

/// Last resort for unexpected foreground errors. Expected failures should still
/// be caught at their action so they can offer a more specific explanation.
abstract final class AppErrorHandler {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool _noticePending = false;
  static DateTime? _lastNotice;

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _notify();
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      developer.log(
        'Unexpected application error',
        error: error,
        stackTrace: stack,
      );
      _notify();
      return true;
    };
    ErrorWidget.builder = (_) => const UnexpectedErrorView();
  }

  static void _notify() {
    final now = DateTime.now();
    if (_noticePending ||
        (_lastNotice != null &&
            now.difference(_lastNotice!) < const Duration(seconds: 7))) {
      return;
    }
    _noticePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noticePending = false;
      final messenger = messengerKey.currentState;
      if (messenger == null || !messenger.mounted) return;
      _lastNotice = DateTime.now();
      try {
        messenger.showSnackBar(
          SnackBar(
            content: UserErrorNotice(ErrorMessages.fallback(ErrorAction.load)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
          ),
        );
      } catch (error, stackTrace) {
        // A failed build may have removed the Scaffold. Its replacement view
        // already explains the problem; do not trigger another error loop.
        developer.log(
          'Could not display the error notice',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
