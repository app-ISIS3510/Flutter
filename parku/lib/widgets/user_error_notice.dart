import 'package:flutter/material.dart';

import '../utils/user_error_message.dart';

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
