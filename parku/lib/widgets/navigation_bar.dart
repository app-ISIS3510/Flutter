import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'design_icon.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const icons = ['map', 'parking', 'heart', 'user'];
    const labels = ['Map', 'Parking lots', 'Favorites', 'Profile'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Semantics(
                button: true,
                selected: currentIndex == i,
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: currentIndex == i
                          ? AppColors.lightPurple
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DesignIcon(
                          icons[i],
                          size: 22,
                          color: currentIndex == i
                              ? AppColors.primary
                              : AppColors.greyText,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: currentIndex == i
                                ? AppColors.primary
                                : AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
