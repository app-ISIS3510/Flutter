
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_error_message.dart';

class SignInScreen extends StatefulWidget {
  final AuthController controller;
  final VoidCallback onSignedIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onForgotPassword;

  const SignInScreen({
    super.key,
    required this.controller,
    required this.onSignedIn,
    required this.onCreateAccount,
    required this.onForgotPassword,
  });

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? emailError;
  String? passwordError;
  String? authError;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';

      if (code == 'invalid_credentials' ||
          message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        return 'Incorrect email or password. Please try again.';
      }

      if (code == 'email_not_confirmed' ||
          message.contains('email not confirmed')) {
        return 'Please verify your email before signing in.';
      }

      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          message.contains('too many requests') ||
          message.contains('rate limit')) {
        return 'Too many attempts. Please try again later.';
      }

      if (message.contains('network') ||
          message.contains('connection') ||
          message.contains('failed to fetch')) {
        return 'Connection problem. Please check your internet and try again.';
      }
    }

    final message = error.toString().toLowerCase();

    if (message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection') ||
        message.contains('network') ||
        message.contains('xmlhttprequest')) {
      return 'Connection problem. Please check your internet and try again.';
    }

    return 'Unable to sign in right now. Please try again.';
  }

  Future<void> _signIn() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    String? newEmailError;
    String? newPasswordError;

    if (email.isEmpty) {
      newEmailError = 'Please enter your email address.';
    } else if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(email)) {
      newEmailError = 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      newPasswordError = 'Please enter your password.';
    }

    setState(() {
      emailError = newEmailError;
      passwordError = newPasswordError;
      authError = null;
    });

    if (newEmailError != null || newPasswordError != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await widget.controller.signIn(
        email: email,
        password: password,
      );

      if (!mounted) return;
      widget.onSignedIn();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        authError = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(
    String hint, {
    bool hasError = false,
  }) {
    final borderRadius = BorderRadius.circular(11);

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.greyText,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFC83D4D)
              : const Color(0xFFE2DEEB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFC83D4D)
              : AppColors.primary,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),
    );
  }

  Widget _fieldError(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFC83D4D),
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFC83D4D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Sign in',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'ParkU',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your campus. Your parking. One less thing to\nworry about.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Email address'),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) {
                        if (emailError != null || authError != null) {
                          setState(() {
                            emailError = null;
                            authError = null;
                          });
                        }
                      },
                      decoration: _inputDecoration(
                        'Email address',
                        hasError: emailError != null,
                      ),
                    ),
                    if (emailError != null)
                      _fieldError(emailError!),
                    const SizedBox(height: 14),
                    _label('Password'),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _signIn(),
                      onChanged: (_) {
                        if (passwordError != null || authError != null) {
                          setState(() {
                            passwordError = null;
                            authError = null;
                          });
                        }
                      },
                      decoration: _inputDecoration(
                        'Password',
                        hasError: passwordError != null,
                      ),
                    ),
                    if (passwordError != null)
                      _fieldError(passwordError!),
                    if (authError != null) ...[
                      const SizedBox(height: 14),
                      AuthErrorMessage(message: authError!),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 43,
                      child: TextButton(
                        onPressed: widget.onForgotPassword,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: isLoading ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 43,
                      child: TextButton(
                        onPressed: widget.onCreateAccount,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.lightPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Find parking near campus and keep track of your stay.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
