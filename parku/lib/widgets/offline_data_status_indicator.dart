import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OfflineDataStatusIndicator extends StatelessWidget {
  final bool isFromCache;
  final DateTime? updatedAt;
  final String title;
  final String description;

  const OfflineDataStatusIndicator({
    super.key,
    required this.isFromCache,
    this.updatedAt,
    this.title = 'Saved data',
    this.description =
        'Showing locally stored information. It may be outdated.',
  });

  @override
  Widget build(BuildContext context) {
    if (!isFromCache) {
      return const SizedBox.shrink();
    }

    final localTime = updatedAt?.toLocal();
    final formattedDate = localTime == null
        ? null
        : '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
              '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightPurple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
                if (formattedDate != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last updated: $formattedDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
