import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';
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
  const AuthGate({super.key});

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
    final code = Uri.base.queryParameters['code'];

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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isProcessingRecovery = false;
        recoveryError = error.toString();
      });
    }
  }

  void _showSignIn() {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    if (isProcessingRecovery) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (recoveryError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The password reset link is invalid or has expired.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      recoveryError = null;
                      currentScreen = AuthScreen.resetPassword;
                    });
                  },
                  child: const Text('Request a new link'),
                ),
              ],
            ),
          ),
        ),
      );
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
          return const MainNavigationScreen();
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
              onOpenEmailApp: () {},
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
