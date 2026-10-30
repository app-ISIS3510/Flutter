
import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_error_message.dart';
import '../utils/user_error_message.dart';

class CreateAccountScreen extends StatefulWidget {
  final AuthController controller;
  final VoidCallback onAccountCreated;
  final VoidCallback onBackToSignIn;

  const CreateAccountScreen({
    super.key,
    required this.controller,
    required this.onAccountCreated,
    required this.onBackToSignIn,
  });

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? fullNameError;
  String? emailError;
  String? passwordError;
  String? authError;
  String? successMessage;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (isLoading) return;

    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    String? newFullNameError;
    String? newEmailError;
    String? newPasswordError;

    if (fullName.isEmpty) {
      newFullNameError = 'Please enter your full name.';
    }

    if (email.isEmpty) {
      newEmailError = 'Please enter your email address.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      newEmailError = 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      newPasswordError = 'Please enter a password.';
    } else if (password.length < 8) {
      newPasswordError = 'Password must be at least 8 characters.';
    }

    setState(() {
      fullNameError = newFullNameError;
      emailError = newEmailError;
      passwordError = newPasswordError;
      authError = null;
      successMessage = null;
    });

    if (newFullNameError != null ||
        newEmailError != null ||
        newPasswordError != null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await widget.controller.signUp(
        fullName: fullName,
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session != null) {
        widget.onAccountCreated();
        return;
      }

      if (response.user != null &&
          response.user!.identities != null &&
          response.user!.identities!.isEmpty) {
        setState(() {
          authError =
              'If this email is already registered, try signing in or resetting your password.';
        });
        return;
      }

      setState(() {
        successMessage =
            'Account request received. If email confirmation is required, check your inbox before signing in.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        authError = userErrorMessage(
          error,
          action: ErrorAction.createAccount,
        );
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
    final radius = BorderRadius.circular(11);

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
        borderRadius: radius,
        borderSide: BorderSide(
          color: hasError
              ? const Color(0xFFC83D4D)
              : const Color(0xFFE2DEEB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
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

  Widget _successMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F5EC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFB7E2CB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF16835B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.darkText,
                fontSize: 13,
                height: 1.4,
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
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
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
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            onPressed: widget.onBackToSignIn,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 29),
                    const Text(
                      'Make room for easier days',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'Create your ParkU account to save parking\nlots and manage your vehicles.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _label('Full name'),
                    TextField(
                      controller: fullNameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      onChanged: (_) {
                        if (fullNameError != null ||
                            authError != null ||
                            successMessage != null) {
                          setState(() {
                            fullNameError = null;
                            authError = null;
                            successMessage = null;
                          });
                        }
                      },
                      decoration: _inputDecoration(
                        'Full name',
                        hasError: fullNameError != null,
                      ),
                    ),
                    if (fullNameError != null)
                      _fieldError(fullNameError!),
                    const SizedBox(height: 14),
                    _label('Email address'),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) {
                        if (emailError != null ||
                            authError != null ||
                            successMessage != null) {
                          setState(() {
                            emailError = null;
                            authError = null;
                            successMessage = null;
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
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _createAccount(),
                      onChanged: (_) {
                        if (passwordError != null ||
                            authError != null ||
                            successMessage != null) {
                          setState(() {
                            passwordError = null;
                            authError = null;
                            successMessage = null;
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
                    const SizedBox(height: 10),
                    const Text(
                      'Use at least 8 characters.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.greyText,
                      ),
                    ),
                    if (authError != null) ...[
                      const SizedBox(height: 14),
                      AuthErrorMessage(message: authError!),
                    ],
                    if (successMessage != null) ...[
                      const SizedBox(height: 14),
                      _successMessage(successMessage!),
                    ],
                    const SizedBox(height: 13),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: isLoading ? null : _createAccount,
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
                                'Create account',
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
                        onPressed: widget.onBackToSignIn,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Already have an account? Sign in',
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
      ),
    );
  }
}
