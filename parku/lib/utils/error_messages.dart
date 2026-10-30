/// Only app-owned validation messages may be shown verbatim.
/// FormatException from a parser or a server must use a safe fallback instead.
class UserInputException extends FormatException {
  const UserInputException(super.message);
}

class OfflineActionException implements Exception {
  const OfflineActionException();
}

enum ErrorAction {
  signIn,
  createAccount,
  resetPassword,
  updatePassword,
  profile,
  startParking,
  updatePickup,
  endParking,
  favorites,
  signOut,
  load,
}

/// Approved presentation text. Remote messages are used only to recognize known
/// errors; they are never interpolated into the text shown to the user.
abstract final class ErrorMessages {
  static String offline(ErrorAction action) => switch (action) {
    ErrorAction.startParking => 'Go online to start parking.',
    ErrorAction.updatePickup => 'Go online to change your pickup time.',
    ErrorAction.endParking =>
      'Go online to end parking. Please try again later.',
    ErrorAction.favorites =>
      'Connect once to load your favorites, then try again.',
    ErrorAction.profile =>
      'Your profile needs a connection. Please try again later.',
    _ => 'You are offline. Please try again later.',
  };
  static const invalidCredentials =
      'The email or password is incorrect. Check your details and try again.';
  static const signInRequired =
      'Your session is no longer available. Please sign in again to continue.';
  static const invalidRecoveryLink =
      'This password reset link has expired or is no longer valid. Request a new link and try again.';

  static String fallback(ErrorAction action) => switch (action) {
    ErrorAction.signIn =>
      'We could not sign you in. Please try again in a moment.',
    ErrorAction.createAccount =>
      'We could not create your account. Please try again in a moment.',
    ErrorAction.resetPassword =>
      'We could not send the reset link. Please try again in a moment.',
    ErrorAction.updatePassword => 'We could not update your password. Please try again or request a new reset link.',
    ErrorAction.profile =>
      'We could not save or load your information. Please try again.',
    ErrorAction.startParking =>
      'We could not start your parking session. Please try again.',
    ErrorAction.updatePickup =>
      'We could not update your pickup time. Please try again.',
    ErrorAction.endParking =>
      'We could not end your parking session. Please try again later.',
    ErrorAction.favorites =>
      'We could not save your favorite preference. Please try again.',
    ErrorAction.signOut => 'We could not sign you out. Please try again.',
    ErrorAction.load => 'Something went wrong. Please try again in a moment.',
  };

  static String auth({
    String? code,
    String? statusCode,
    required String message,
    required ErrorAction action,
  }) {
    // Older SDK responses sometimes omit code. Match only known full messages.
    final knownCode =
        code ??
        switch (message.trim().toLowerCase()) {
          'invalid login credentials' => 'invalid_credentials',
          'email not confirmed' => 'email_not_confirmed',
          'user already registered' => 'user_already_exists',
          'new password should be different from the old password.' =>
            'same_password',
          _ => null,
        };
    if (statusCode == '429') {
      return 'Too many attempts in a short time. Wait a few minutes and try again.';
    }
    return switch (knownCode) {
      'invalid_credentials' || 'user_not_found' =>
        action == ErrorAction.signIn ? invalidCredentials : fallback(action),
      'email_not_confirmed' => 'Please confirm your email before signing in. Check your inbox and spam folder.',
      'user_already_exists' || 'email_exists' =>
        'An account already uses this email. Sign in or reset your password.',
      'email_address_invalid' || 'email_address_not_authorized' =>
        'This email address cannot be used. Check it or try another address.',
      'weak_password' => 'Choose a stronger password with at least 8 characters, including letters, numbers and a symbol.',
      'same_password' =>
        'Choose a new password that is different from your current password.',
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' ||
      'over_sms_send_rate_limit' =>
        'Too many attempts in a short time. Wait a few minutes and try again.',
      'signup_disabled' =>
        'New accounts are temporarily unavailable. Please try again later.',
      'user_banned' => 'This account cannot sign in right now. Please contact the ParkU team for help.',
      'otp_expired' ||
      'flow_state_expired' ||
      'flow_state_not_found' ||
      'bad_code_verifier' => invalidRecoveryLink,
      'session_not_found' ||
      'session_expired' ||
      'refresh_token_not_found' ||
      'refresh_token_already_used' ||
      'bad_jwt' ||
      'no_authorization' =>
        action == ErrorAction.updatePassword
            ? invalidRecoveryLink
            : signInRequired,
      _ =>
        action == ErrorAction.signIn && statusCode == '401'
            ? invalidCredentials
            : action != ErrorAction.signIn && statusCode == '401'
            ? signInRequired
            : fallback(action),
    };
  }

  static String database({
    String? code,
    required String message,
    required ErrorAction action,
  }) {
    const businessErrors = {
      'NO_AVAILABLE_SPACES': 'This parking lot has no available spaces. Please choose another parking lot.',
      'ACTIVE_SESSION_EXISTS': 'You already have an active parking session. Open My parking to see it.',
      'VEHICLE_NOT_FOUND': 'This vehicle is no longer available. Refresh your vehicles and choose another one.',
      'VEHICLE_IN_USE': 'This vehicle has an active parking session. End it before deleting the vehicle.',
      'INVALID_VEHICLE_TYPE':
          'Choose a car or motorcycle before starting parking.',
      'INVALID_PICKUP_TIME':
          'Choose a pickup time later than the current time.',
      'PARKING_NOT_FOUND': 'This parking lot is no longer available. Return to the parking list and choose another one.',
      'SIGN_IN_REQUIRED': signInRequired,
    };
    for (final entry in businessErrors.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(message)) return entry.value;
    }
    return switch (code) {
      '23505' =>
        action == ErrorAction.profile
            ? 'You have already saved this license plate.'
            : 'This information has already been saved. Refresh and try again.',
      '23503' =>
        'This item has changed or is still in use. Refresh and try again.',
      '42501' => 'You do not have permission to perform this action.',
      'PGRST301' || 'PGRST302' || 'PGRST303' => signInRequired,
      'PGRST116' =>
        'This information is no longer available. Refresh and try again.',
      _ => fallback(action),
    };
  }
}
