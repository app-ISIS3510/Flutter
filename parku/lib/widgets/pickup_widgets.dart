import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design_icon.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const ScreenHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const DesignIcon('arrow'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ),
      ],
    );
  }
}

class PickupButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final double height;

  const PickupButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.background = AppColors.primary,
    this.foreground = AppColors.white,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

class SuggestedTimes extends StatelessWidget {
  final String selectedTime;
  final ValueChanged<String> onChanged;

  const SuggestedTimes({
    super.key,
    required this.selectedTime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const times = ['3:30', '4:00', '4:30'];
    return Row(
      children: [
        for (int i = 0; i < times.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              selected: selectedTime == times[i],
              child: PickupButton(
                text: times[i],
                background: AppColors.lightPurple,
                foreground: AppColors.primary,
                onPressed: () => onChanged(times[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
