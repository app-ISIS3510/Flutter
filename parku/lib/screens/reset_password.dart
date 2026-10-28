
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_error_message.dart';

class ResetPasswordScreen extends StatefulWidget {
  final AuthController controller;
  final VoidCallback onBackToSignIn;
  final ValueChanged<String> onEmailSent;

  const ResetPasswordScreen({
    super.key,
    required this.controller,
    required this.onBackToSignIn,
    required this.onEmailSent,
  });

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final emailController = TextEditingController();

  bool isLoading = false;
  String? emailError;
  String? authError;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  String _friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';

      if (code == 'email_address_invalid' ||
          message.contains('invalid email') ||
          message.contains('email address is invalid')) {
        return 'Please enter a valid email address.';
      }

      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          message.contains('rate limit') ||
          message.contains('too many requests') ||
          message.contains('for security purposes')) {
        return 'Too many requests. Please wait a while before trying again.';
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

    return 'We could not process your request right now. Please try again later.';
  }

  Future<void> _sendResetLink() async {
    if (isLoading) return;

    final email = emailController.text.trim();

    String? newEmailError;

    if (email.isEmpty) {
      newEmailError = 'Please enter your email address.';
    } else if (!RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    ).hasMatch(email)) {
      newEmailError = 'Please enter a valid email address.';
    }

    setState(() {
      emailError = newEmailError;
      authError = null;
    });

    if (newEmailError != null) return;

    setState(() {
      isLoading = true;
    });

    try {
      await widget.controller.resetPassword(email: email);

      if (!mounted) return;

      widget.onEmailSent(email);
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

  InputDecoration _inputDecoration() {
    final hasError = emailError != null;
    final radius = BorderRadius.circular(10);

    return InputDecoration(
      hintText: 'Email address',
      hintStyle: const TextStyle(
        color: AppColors.greyText,
        fontSize: 14,
      ),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFC83D4D)
              : const Color(0xFFE1DDEA),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFC83D4D)
              : AppColors.primary,
          width: 1.3,
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
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 37,
                          height: 37,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: widget.onBackToSignIn,
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Reset password',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Forgot your password?',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email and we will send you a\npassword reset link.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Email address',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _sendResetLink(),
                      onChanged: (_) {
                        if (emailError != null || authError != null) {
                          setState(() {
                            emailError = null;
                            authError = null;
                          });
                        }
                      },
                      decoration: _inputDecoration(),
                    ),
                    if (emailError != null)
                      _fieldError(emailError!),
                    if (authError != null) ...[
                      const SizedBox(height: 14),
                      AuthErrorMessage(message: authError!),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: isLoading ? null : _sendResetLink,
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
                                'Send reset link',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 43,
                      child: TextButton(
                        onPressed: widget.onBackToSignIn,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Back to sign in',
                          style: TextStyle(
                            fontSize: 14,
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
      ),
    );
  }
}
