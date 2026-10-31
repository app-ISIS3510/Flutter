import 'package:flutter/material.dart';

import '../utils/user_error_message.dart';
import '../theme/app_theme.dart';

/// Shared, readable presentation for expected user-facing failures.
class UserErrorNotice extends StatelessWidget {
  final String message;
  const UserErrorNotice(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCECF0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2CED5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFA3313F),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF802938),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showUserError(
  BuildContext context,
  Object? error, {
  ErrorAction action = ErrorAction.load,
}) {
  showUserMessage(context, userErrorMessage(error, action: action));
}

void showUserMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: UserErrorNotice(message),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 7),
    ),
  );
}

/// A brief, neutral notice for a successful local action awaiting sync.
void showUserInfo(
  BuildContext context,
  String message, {
  IconData icon = Icons.cloud_upload_outlined,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 3),
      content: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightPurple,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
