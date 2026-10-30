import 'dart:io';

import 'package:parku/utils/auth_validation.dart';
import 'package:parku/utils/error_messages.dart';
import 'package:parku/state/favorite_status_state.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  const secret = 'PRIVATE_BACKEND_DETAIL_123';
  var checks = 0;
  check(
    ErrorMessages.offline(ErrorAction.startParking).contains('start parking') &&
        !ErrorMessages.offline(ErrorAction.startParking).contains('profile'),
    'Park here must explain the blocked parking action, not an unrelated profile failure.',
  );
  check(
    ErrorMessages.offline(ErrorAction.updatePickup).contains('pickup time'),
    'Changing pickup time must explain that it requires a connection.',
  );
  check(
    ErrorMessages.offline(ErrorAction.endParking).contains('try again later') &&
        ErrorMessages.fallback(ErrorAction.endParking)
            .contains('try again later'),
    'Ending parking must invite retry later, not an immediate repeated request.',
  );
  check(
    ErrorMessages.offline(ErrorAction.favorites).contains('Connect once'),
    'Unknown offline favorite status must explain how to initialize it.',
  );
  const unknown = FavoriteStatusState(
    errorMessage: 'Connect once to load your favorites.',
  );
  check(
    unknown.isFavorite == null && !unknown.isBusy,
    'Failed favorite reads must retain unknown status, not pretend the item is not saved.',
  );
  const loadingKnown = FavoriteStatusState(isFavorite: true, isBusy: true);
  check(
    loadingKnown.isFavorite == true && loadingKnown.isBusy,
    'Favorite refresh must retain the last known preference while checking.',
  );
  checks += 6;
  String auth(
    String? code, {
    String? status,
    String message = secret,
    ErrorAction action = ErrorAction.signIn,
  }) => ErrorMessages.auth(
    code: code,
    statusCode: status,
    message: message,
    action: action,
  );
  for (final code in ['invalid_credentials', 'user_not_found']) {
    check(
      auth(code) == ErrorMessages.invalidCredentials,
      'Wrong passwords and unknown accounts must have the same safe explanation.',
    );
    checks++;
  }
  check(
    auth(null, message: 'Invalid login credentials') ==
        ErrorMessages.invalidCredentials,
    'Older responses without an error code must be recognized.',
  );
  check(
    auth('unexpected', status: '401') == ErrorMessages.invalidCredentials,
    'Unauthorized sign-in must explain that credentials should be checked.',
  );
  check(
    auth('email_not_confirmed').contains('confirm your email'),
    'Unconfirmed accounts need an email confirmation instruction.',
  );
  check(
    auth(
      'user_already_exists',
      action: ErrorAction.createAccount,
    ).contains('reset your password'),
    'Existing accounts must offer sign-in or password recovery.',
  );
  check(
    auth(
      'same_password',
      action: ErrorAction.updatePassword,
    ).contains('different'),
    'Reused passwords must explain how to correct the input.',
  );
  check(
    auth('otp_expired', action: ErrorAction.updatePassword) ==
        ErrorMessages.invalidRecoveryLink,
    'Expired recovery links must request a new link.',
  );
  check(
    auth('session_expired') == ErrorMessages.signInRequired,
    'Expired sessions must ask the user to sign in again.',
  );
  check(
    auth('session_expired', action: ErrorAction.updatePassword) ==
        ErrorMessages.invalidRecoveryLink,
    'Expired password-recovery sessions must request a fresh link.',
  );
  check(
    auth('unknown', status: '429').contains('Wait a few minutes'),
    'Rate limits must ask the user to wait rather than repeat immediately.',
  );
  checks += 10;

  for (final action in ErrorAction.values) {
    final outputs = [
      auth('unknown_code', action: action),
      auth(null, action: action),
      auth(null, message: 'AuthApiException: $secret', action: action),
      ErrorMessages.database(code: 'XX000', message: secret, action: action),
    ];
    for (final output in outputs) {
      check(
        output == ErrorMessages.fallback(action),
        'Unknown failures must use the contextual fallback.',
      );
      check(
        !output.contains(secret) &&
            !output.contains('Exception') &&
            !output.contains('XX000'),
        'Internal details must never reach the UI.',
      );
      checks++;
    }
  }
  const parkingCases = {
    'NO_AVAILABLE_SPACES': 'choose another parking lot',
    'ACTIVE_SESSION_EXISTS': 'Open My parking',
    'VEHICLE_NOT_FOUND': 'Refresh your vehicles',
    'VEHICLE_IN_USE': 'End it before deleting',
    'INVALID_PICKUP_TIME': 'later than the current time',
    'PARKING_NOT_FOUND': 'Return to the parking list',
    'SIGN_IN_REQUIRED': 'sign in again',
  };
  for (final entry in parkingCases.entries) {
    final output = ErrorMessages.database(
      code: 'P0001',
      message: '${entry.key}: $secret',
      action: ErrorAction.startParking,
    );
    check(
      output.contains(entry.value) && !output.contains(secret),
      'Business errors must explain the next action without remote details.',
    );
    checks++;
  }
  check(
    ErrorMessages.database(
          code: 'P0001',
          message: 'NOT_NO_AVAILABLE_SPACES_INTERNAL',
          action: ErrorAction.startParking,
        ) ==
        ErrorMessages.fallback(ErrorAction.startParking),
    'Partial internal token matches must not misclassify an unknown failure.',
  );
  check(
    ErrorMessages.database(
      code: '23505',
      message: secret,
      action: ErrorAction.profile,
    ).contains('already saved this license plate'),
    'Duplicate plates must have a clear explanation.',
  );
  check(
    ErrorMessages.database(
      code: '42501',
      message: secret,
      action: ErrorAction.load,
    ).contains('permission'),
    'Permission errors must not expose database policy details.',
  );
  checks += 3;

  void invalid(void Function() validate, String expected) {
    try {
      validate();
      throw StateError('Invalid input was accepted.');
    } on UserInputException catch (error) {
      check(
        error.message.contains(expected),
        'Validation must explain how to fix the input.',
      );
      checks++;
    }
  }

  invalid(() => AuthValidation.email(''), 'email address');
  for (final value in ['not-an-email', 'a@', 'a @example.com', 'a@example']) {
    invalid(() => AuthValidation.email(value), 'valid email address');
  }
  invalid(() => AuthValidation.name('  '), 'full name');
  invalid(() => AuthValidation.password(''), 'password');
  invalid(() => AuthValidation.password('short', isNew: true), '8 characters');
  AuthValidation.email(' name+parking@example.com ');
  AuthValidation.name('Camila Fajardo');
  AuthValidation.password('password-with-spaces ', isNew: true);
  // Do not apply the new-password policy to existing sign-in credentials.
  AuthValidation.password('short');
  stdout.writeln(
    '$checks user-facing error checks passed, including invalid credentials, validation, recovery, business rules, and internal-detail suppression.',
  );
}
