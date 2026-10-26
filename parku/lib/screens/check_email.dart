import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CheckEmailScreen extends StatelessWidget {
  final String email;
  final VoidCallback onUseAnotherEmail;
  final VoidCallback onBackToSignIn;

  const CheckEmailScreen({
    super.key,
    required this.email,
    required this.onUseAnotherEmail,
    required this.onBackToSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                13,
                18,
                13,
                24,
              ),
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
                          onPressed: onUseAnotherEmail,
                          icon: const Icon(
                            Icons.arrow_back,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Check your email',
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
                    'Check your inbox',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'If an account exists for this email, you will\n'
                    'receive a password reset link.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightPurple,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 43,
                    child: TextButton(
                      onPressed: onUseAnotherEmail,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.lightPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text(
                        'Use another email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 43,
                    child: TextButton(
                      onPressed: onBackToSignIn,
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
    );
  }
}
