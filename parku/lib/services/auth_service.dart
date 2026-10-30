import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../utils/auth_validation.dart';

class AuthService {
  final AuthRepository repository;

  AuthService(this.repository);

  User? get currentUser => repository.currentUser;

  bool get isLoggedIn => currentUser != null;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    AuthValidation.email(email);
    AuthValidation.password(password);

    return repository.signIn(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    AuthValidation.name(fullName);
    AuthValidation.email(email);
    AuthValidation.password(password, isNew: true);

    return repository.signUp(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  Future<void> resetPassword({required String email}) {
    AuthValidation.email(email);

    return repository.resetPassword(email: email);
  }

  Future<UserResponse> updatePassword({required String password}) {
    AuthValidation.password(password, isNew: true);

    return repository.updatePassword(password: password);
  }

  Future<void> signOut() {
    return repository.signOut();
  }
}
