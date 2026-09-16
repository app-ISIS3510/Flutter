import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _navItem(
            index: 0,
            icon: Icons.map_outlined,
            label: 'Map',
            selected: currentIndex == 0,
          ),
          _navItem(
            index: 1,
            icon: Icons.local_parking_outlined,
            label: 'Parking lots',
            selected: currentIndex == 1,
          ),
          _navItem(
            index: 2,
            icon: Icons.favorite_border,
            label: 'Favorites',
            selected: currentIndex == 2,
          ),
          _navItem(
            index: 3,
            icon: Icons.person_outline,
            label: 'Profile',
            selected: currentIndex == 3,
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.lightPurple
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? AppColors.primary
                    : AppColors.greyText,
                size: 25,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.primary
                      : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}