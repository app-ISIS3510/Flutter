
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import 'check_email.dart';
import 'create_account.dart';
import 'main_navigation.dart';
import 'new_password.dart';
import 'password_updated.dart';
import 'reset_password.dart';
import 'sign_in.dart';

enum AuthScreen {
  signIn,
  createAccount,
  resetPassword,
  checkEmail,
  newPassword,
  passwordUpdated,
}

class AuthGate extends StatefulWidget {
  final ProfileService? profileService;
  final SessionService? sessionService;

  const AuthGate({
    super.key,
    this.profileService,
    this.sessionService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthController authController;

  AuthScreen currentScreen = AuthScreen.signIn;
  String resetEmail = '';

  bool isProcessingRecovery = true;
  String? recoveryError;

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;
    final repository = AuthRepository(supabase);
    final service = AuthService(repository);

    authController = AuthController(service);

    _handleRecoveryLink();
  }

 
Future<void> _handleRecoveryLink() async {
  final parameters = Uri.base.queryParameters;
  final fragmentParameters = Uri.splitQueryString(
    Uri.base.fragment.contains('?')
        ? Uri.base.fragment.split('?').last
        : Uri.base.fragment,
  );

  final errorCode =
      parameters['error_code'] ?? fragmentParameters['error_code'];

  final error =
      parameters['error'] ?? fragmentParameters['error'];

  if (error != null || errorCode != null) {
    if (!mounted) return;

    setState(() {
      isProcessingRecovery = false;
      recoveryError =
          'This password reset link is invalid or has expired.';
    });

    return;
  }

  final code = parameters['code'] ?? fragmentParameters['code'];

  if (code == null || code.isEmpty) {
    if (!mounted) return;

    setState(() {
      isProcessingRecovery = false;
    });

    return;
  }

  try {
    await Supabase.instance.client.auth.exchangeCodeForSession(code);

    if (!mounted) return;

    setState(() {
      currentScreen = AuthScreen.newPassword;
      isProcessingRecovery = false;
      recoveryError = null;
    });
  } catch (_) {
    if (!mounted) return;

    setState(() {
      isProcessingRecovery = false;
      recoveryError =
          'This password reset link is invalid or has expired.';
    });
  }
}


  void _showSignIn() {
    setState(() {
      recoveryError = null;
      currentScreen = AuthScreen.signIn;
    });
  }

  void _showCreateAccount() {
    setState(() {
      currentScreen = AuthScreen.createAccount;
    });
  }

  void _showResetPassword() {
    setState(() {
      recoveryError = null;
      currentScreen = AuthScreen.resetPassword;
    });
  }

  void _showCheckEmail(String email) {
    setState(() {
      resetEmail = email;
      currentScreen = AuthScreen.checkEmail;
    });
  }

  void _showNewPassword() {
    setState(() {
      currentScreen = AuthScreen.newPassword;
    });
  }

  void _showPasswordUpdated() {
    setState(() {
      currentScreen = AuthScreen.passwordUpdated;
    });
  }

  Future<void> _backToSignInAfterPasswordUpdate() async {
    await authController.signOut();

    if (!mounted) return;

    setState(() {
      currentScreen = AuthScreen.signIn;
    });
  }

  Widget _recoveryErrorScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ParkU',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Link expired',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF2C5CA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFC83D4D),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recoveryError!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _showResetPassword,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text(
                        'Request a new link',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _showSignIn,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text(
                        'Back to sign in',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isProcessingRecovery) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (recoveryError != null) {
      return _recoveryErrorScreen();
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        final session = Supabase.instance.client.auth.currentSession;

        if (authState?.event == AuthChangeEvent.passwordRecovery &&
            currentScreen != AuthScreen.newPassword &&
            currentScreen != AuthScreen.passwordUpdated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (currentScreen != AuthScreen.newPassword &&
                currentScreen != AuthScreen.passwordUpdated) {
              _showNewPassword();
            }
          });
        }

        if (currentScreen == AuthScreen.newPassword) {
          return NewPasswordScreen(
            controller: authController,
            onPasswordUpdated: _showPasswordUpdated,
            onBack: _showSignIn,
          );
        }

        if (currentScreen == AuthScreen.passwordUpdated) {
          return PasswordUpdatedScreen(
            onBackToSignIn: _backToSignInAfterPasswordUpdate,
          );
        }

        if (session != null) {
          return MainNavigationScreen(
            key: ValueKey(session.user.id),
            profileService: widget.profileService,
            sessionService: widget.sessionService,
          );
        }

        switch (currentScreen) {
          case AuthScreen.createAccount:
            return CreateAccountScreen(
              controller: authController,
              onAccountCreated: () {
                setState(() {});
              },
              onBackToSignIn: _showSignIn,
            );

          case AuthScreen.resetPassword:
            return ResetPasswordScreen(
              controller: authController,
              onBackToSignIn: _showSignIn,
              onEmailSent: _showCheckEmail,
            );

          case AuthScreen.checkEmail:
            return CheckEmailScreen(
              email: resetEmail,
              onUseAnotherEmail: _showResetPassword,
              onBackToSignIn: _showSignIn,
            );

          case AuthScreen.signIn:
            return SignInScreen(
              controller: authController,
              onSignedIn: () {
                setState(() {});
              },
              onCreateAccount: _showCreateAccount,
              onForgotPassword: _showResetPassword,
            );

          case AuthScreen.newPassword:
            return NewPasswordScreen(
              controller: authController,
              onPasswordUpdated: _showPasswordUpdated,
              onBack: _showSignIn,
            );

          case AuthScreen.passwordUpdated:
            return PasswordUpdatedScreen(
              onBackToSignIn: _backToSignInAfterPasswordUpdate,
            );
        }
      },
    );
  }
}
