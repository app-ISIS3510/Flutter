import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';

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

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await widget.controller.signUp(
        fullName: fullNameController.text,
        email: emailController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      if (response.session != null) {
        widget.onAccountCreated();
        return;
      }

      widget.onBackToSignIn();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.greyText, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Color(0xFFE2DEEB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
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
                      decoration: _inputDecoration('Full name'),
                    ),
                    const SizedBox(height: 14),
                    _label('Email address'),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: _inputDecoration('Email address'),
                    ),
                    const SizedBox(height: 14),
                    _label('Password'),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _createAccount(),
                      decoration: _inputDecoration('Password'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Use at least 8 characters.',
                      style: TextStyle(fontSize: 11, color: AppColors.greyText),
                    ),
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
                                style: TextStyle(fontWeight: FontWeight.w600),
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
