import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Does not include the exception, stack trace, or backend response.
class UnexpectedErrorView extends StatelessWidget {
  final bool duringStartup;
  const UnexpectedErrorView({super.key, this.duringStartup = false});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 44,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                duringStartup
                    ? 'ParkU could not start'
                    : 'We could not display this screen',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please close and reopen the app. If this keeps happening, try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
