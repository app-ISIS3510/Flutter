import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class AuthController {
  final AuthService service;

  AuthController(this.service);

  User? get currentUser => service.currentUser;

  bool get isLoggedIn => service.isLoggedIn;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return service.signIn(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return service.signUp(fullName: fullName, email: email, password: password);
  }

  Future<void> resetPassword({required String email}) {
    return service.resetPassword(email: email);
  }

  Future<UserResponse> updatePassword({required String password}) {
    return service.updatePassword(password: password);
  }

  Future<void> signOut() {
    return service.signOut();
  }
}
