import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/navigation_bar.dart';
import '../../widgets/pickup_widgets.dart';

TextStyle profileText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.darkText,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  height: 1.35,
  fontWeight: weight,
  color: color,
);

class ProfilePage extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final ValueChanged<int> onNavTap;
  final double gap;
  final Widget child;
  const ProfilePage({
    super.key,
    required this.title,
    this.onBack,
    required this.onNavTap,
    required this.child,
    this.gap = 24,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(title: title, onBack: onBack),
                  SizedBox(height: gap),
                  child,
                ],
              ),
            ),
          ),
          NavBar(currentIndex: 3, onTap: onNavTap),
        ],
      ),
    ),
  );
}

class ProfileButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final double height;
  const ProfileButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.background = AppColors.primary,
    this.foreground = Colors.white,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: .6),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: height < 52 ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: profileText(16, weight: FontWeight.w600),
      ),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class ProfileCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const ProfileCard({
    super.key,
    required this.child,
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class ProfileError extends StatelessWidget {
  final String message;
  const ProfileError(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCECF0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: profileText(12, color: const Color(0xFFA3313F)),
      ),
    ),
  );
}

class ProfileField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enabled;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;
  const ProfileField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.enabled = true,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: profileText(14, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        enabled: enabled,
        textCapitalization: capitalization,
        onChanged: onChanged,
        autocorrect: false,
        style: profileText(16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: profileText(16, color: AppColors.greyText),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E0EF)),
          ),
          errorMaxLines: 2,
        ),
      ),
    ],
  );
}
