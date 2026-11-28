import 'package:flutter/material.dart';

import '../models/parking_summary.dart';
import '../theme/app_theme.dart';
import 'profile/profile_widgets.dart';

class ParkingSummaryScreen extends StatelessWidget {
  final ParkingSummary summary;
  final bool isSavedCopy;
  final VoidCallback onDone;
  final ValueChanged<int> onNavTap;

  const ParkingSummaryScreen({
    super.key,
    required this.summary,
    required this.onDone,
    required this.onNavTap,
    this.isSavedCopy = false,
  });

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

  String _formatCurrency(num value) {
    final parts = value.toStringAsFixed(2).split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

    return parts.last == '00' ? 'COP $integer' : 'COP $integer.${parts.last}';
  }

  String get _vehicle {
    final type = switch (summary.vehicleType) {
      'car' => 'Car',
      'motorcycle' => 'Motorcycle',
      _ => 'Vehicle',
    };

    final plate = summary.vehiclePlate;

    return plate == null || plate.isEmpty ? type : '$type - $plate';
  }

  String get _total {
    final total = summary.totalCost;

    if (total == null) return 'Unavailable';

    return _formatCurrency(total);
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: profileText(16, color: AppColors.greyText),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: profileText(
                highlight ? 21 : 16,
                weight: highlight ? FontWeight.w700 : FontWeight.w400,
                color: highlight ? AppColors.primary : AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      title: 'Parking summary',
      gap: 40,
      onNavTap: onNavTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSavedCopy) ...[
            const ProfileNotice('Saved copy'),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.parkingName,
                  style: profileText(25, weight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  summary.parkingAddress ?? 'Address unavailable',
                  style: profileText(16, color: AppColors.greyText),
                ),
                const SizedBox(height: 24),
                _summaryRow('Vehicle', _vehicle),
                _summaryRow('Started', _formatTime(summary.startedAt)),
                _summaryRow('Ended', _formatTime(summary.endedAt)),
                _summaryRow('Duration', '${summary.durationMinutes}min'),
                const SizedBox(height: 8),
                _summaryRow('Total', _total, highlight: true),
                const SizedBox(height: 24),
                ProfileButton(text: 'Done', height: 56, onPressed: onDone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
