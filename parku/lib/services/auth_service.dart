import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';

class AuthService {
  final AuthRepository repository;

  AuthService(this.repository);

  User? get currentUser => repository.currentUser;

  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty) {
      throw Exception('Email is required');
    }

    if (password.isEmpty) {
      throw Exception('Password is required');
    }

    return repository.signIn(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    if (fullName.trim().isEmpty) {
      throw Exception('Full name is required');
    }

    if (email.trim().isEmpty) {
      throw Exception('Email is required');
    }

    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters');
    }

    return repository.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword({required String email}) {
    if (email.trim().isEmpty) {
      throw Exception('Email is required');
    }

    return repository.resetPassword(email: email);
  }

  Future<UserResponse> updatePassword({required String password}) {
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters');
    }

    return repository.updatePassword(password: password);
  }

  Future<void> signOut() {
    return repository.signOut();
  }
}
