import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/design_icon.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class FavoritesScreen extends StatelessWidget {
  final List<Map<String, String>> favorites;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onNavTap;
  final ValueChanged<Map<String, String>> onSelectParking;

  const FavoritesScreen({
    super.key,
    required this.favorites,
    required this.onRemove,
    required this.onNavTap,
    required this.onSelectParking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  24,
                ),
                children: [
                  const ScreenHeader(
                    title: 'Favorites',
                  ),
                  const SizedBox(height: 33),
                  const Text(
                    'Your saved places, always handy.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.greyText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < favorites.length; i++) ...[
                    InkWell(
                      onTap: () {
                        onSelectParking(favorites[i]);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const DesignIcon('heart'),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    favorites[i]['name'] ?? 'Parking lot',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.darkText,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.greyText,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              favorites[i]['address'] ??
                                  'Address unavailable',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.greyText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            PickupButton(
                              text: 'Remove',
                              height: 44,
                              background: AppColors.white,
                              foreground: AppColors.primary,
                              onPressed: () {
                                onRemove(i);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < favorites.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            NavBar(
              currentIndex: 2,
              onTap: onNavTap,
            ),
          ],
        ),
      ),
    );
  }
}