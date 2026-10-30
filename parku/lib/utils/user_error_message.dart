import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_messages.dart';

export 'error_messages.dart' show ErrorAction, UserInputException;

String userErrorMessage(
  Object? error, {
  ErrorAction action = ErrorAction.load,
}) {
  if (error is UserInputException) return error.message;
  if (error is OfflineActionException) {
    return ErrorMessages.offline(action);
  }
  if (error is AuthException) {
    // App-owned auth guards also arrive here, without a server error code.
    if (const {
      'Sign in to continue.',
      'The signed-in account changed.',
      'Session belongs to another account.',
    }.contains(error.message)) {
      return ErrorMessages.signInRequired;
    }
    return ErrorMessages.auth(
      code: error.code,
      statusCode: error.statusCode,
      message: error.message,
      action: action,
    );
  }
  if (error is PostgrestException) {
    return ErrorMessages.database(
      code: error.code,
      message: error.message,
      action: action,
    );
  }
  if (error is TimeoutException &&
      const {
        ErrorAction.startParking,
        ErrorAction.updatePickup,
        ErrorAction.endParking,
      }.contains(action)) {
    if (action == ErrorAction.endParking) {
      return 'Could not confirm the end of parking. Check My parking when online, then try again later.';
    }
    return 'Could not confirm the request. Reconnect and check My parking before trying again.';
  }
  return ErrorMessages.fallback(action);
}
