import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'pickup_widgets.dart';

class FavoritesHeader extends StatelessWidget {
  final String? notice;
  final VoidCallback? onRefresh;

  const FavoritesHeader({super.key, this.notice, this.onRefresh});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(child: ScreenHeader(title: 'Favorites')),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              tooltip: 'Refresh favorites',
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            ),
        ],
      ),
      if (notice != null) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.cloud_sync_outlined,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notice!,
                style: const TextStyle(fontSize: 13, color: AppColors.greyText),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
