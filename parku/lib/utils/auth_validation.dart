import 'error_messages.dart';

abstract final class AuthValidation {
  static void email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const UserInputException('Enter your email address to continue.');
    }
    if (trimmed.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed)) {
      throw const UserInputException(
        'Enter a valid email address, such as name@example.com.',
      );
    }
  }

  static void password(String value, {bool isNew = false}) {
    if (value.isEmpty) {
      throw const UserInputException('Enter your password to continue.');
    }
    if (isNew && value.length < 8) {
      throw const UserInputException(
        'Choose a password with at least 8 characters.',
      );
    }
  }

  static void name(String value) {
    if (value.trim().isEmpty) {
      throw const UserInputException(
        'Enter your full name to create your account.',
      );
    }
    if (value.trim().length > 100) {
      throw const UserInputException(
        'Use 100 characters or fewer for your name.',
      );
    }
  }
}
