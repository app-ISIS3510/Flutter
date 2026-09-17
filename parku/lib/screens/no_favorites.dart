import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/design_icon.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class NoFavoritesScreen extends StatelessWidget {
  final ValueChanged<int> onNavTap;

  const NoFavoritesScreen({super.key, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeader(title: 'Favorites'),
                    const SizedBox(height: 97),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DesignIcon('heart1', size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Your favorites start here',
                            style: TextStyle(
                              fontSize: 25,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Save a parking lot from its details to find it faster next time.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PickupButton(
                            text: 'Explore parking lots',
                            onPressed: () => onNavTap(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            NavBar(currentIndex: 2, onTap: onNavTap),
          ],
        ),
      ),
    );
  }
}
