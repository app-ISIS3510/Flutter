import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onMyVehicles;
  final VoidCallback onMyParking;
  final VoidCallback onMyFavorites;
  final VoidCallback onSignOut;
  final ValueChanged<int> onNavTap;

  const ProfileScreen({
    super.key,
    required this.onEditProfile,
    required this.onMyVehicles,
    required this.onMyParking,
    required this.onMyFavorites,
    required this.onSignOut,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    final metadata = user?.userMetadata;

    final fullName = metadata?['full_name']?.toString().trim();

    final displayName = fullName != null && fullName.isNotEmpty
        ? fullName
        : 'ParkU user';

    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'My profile',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 29),

                    Container(
                      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 57,
                              height: 57,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 13),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.greyText,
                            ),
                          ),
                          const SizedBox(height: 13),
                          SizedBox(
                            height: 46,
                            child: FilledButton(
                              onPressed: onEditProfile,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: const Text(
                                'Edit profile',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    _ProfileOption(
                      icon: Icons.directions_car_outlined,
                      title: 'My vehicles',
                      subtitle: 'Add your car or motorcycle plate',
                      onTap: onMyVehicles,
                    ),

                    const SizedBox(height: 13),

                    _ProfileOption(
                      icon: Icons.timer_outlined,
                      title: 'My parking',
                      subtitle: 'Check your parking and pickup time',
                      onTap: onMyParking,
                    ),

                    const SizedBox(height: 13),

                    _ProfileOption(
                      icon: Icons.favorite_border,
                      title: 'My favorites',
                      subtitle: 'Your saved parking lots',
                      onTap: onMyFavorites,
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Everything you need to get to campus and back.',
                      style: TextStyle(fontSize: 12, color: AppColors.greyText),
                    ),

                    const SizedBox(height: 15),

                    SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: onSignOut,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _ProfileBottomNavigation(onNavTap: onNavTap),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 65,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 27,
                  child: Icon(icon, size: 23, color: AppColors.primary),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.greyText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBottomNavigation extends StatelessWidget {
  final ValueChanged<int> onNavTap;

  const _ProfileBottomNavigation({required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.map_outlined,
            label: 'Map',
            onTap: () => onNavTap(0),
          ),
          _NavItem(
            icon: Icons.local_parking_outlined,
            label: 'Parking lots',
            onTap: () => onNavTap(1),
          ),
          _NavItem(
            icon: Icons.favorite_border,
            label: 'Favorites',
            onTap: () => onNavTap(2),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: true,
            onTap: () => onNavTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: selected ? AppColors.lightPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.greyText,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
