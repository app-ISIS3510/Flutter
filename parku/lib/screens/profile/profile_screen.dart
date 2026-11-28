import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../controllers/analytics_controller.dart';
import '../../utils/screen_load_reporter.dart';
import '../../utils/screen_time_observer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/design_icon.dart';
import 'edit_profile_screen.dart';
import 'vehicles_screen.dart';
import 'profile_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileController controller;
  final ValueChanged<int> onNavTap;
  final VoidCallback onMyParking;
  final VoidCallback onSignedOut;
  final Future<void> Function()? onSigningOut;
  final VoidCallback onAnalyticsDashboard;
  final VoidCallback? onParkingHistory;
  final VoidCallback? onLastParkingSummary;
  final AnalyticsController? analytics;
  const ProfileScreen({
    super.key,
    required this.controller,
    required this.onNavTap,
    required this.onMyParking,
    required this.onAnalyticsDashboard,
    required this.onSignedOut,
    this.onParkingHistory,
    this.onLastParkingSummary,
    this.onSigningOut,
    this.analytics,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ScreenLoadReporter? _screenLoad;
  @override
  void initState() {
    super.initState();
    _screenLoad = ScreenLoadReporter(widget.analytics, 'profile');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.controller.load();

      if (!mounted) return;

      setState(() {});
      _screenLoad?.presented(
        context,
        source: widget.controller.usingSavedData
            ? 'sqlite'
            : widget.controller.error == null
            ? 'network'
            : 'none',
        failed: widget.controller.error != null,
      );
    });
  }

  @override
  void dispose() {
    _screenLoad?.cancel();
    super.dispose();
  }

  void _open(String name, Widget screen) {
    widget.controller.clearError();
    Navigator.of(context)
        .push(ScreenTimeRoute<void>(screen: name, builder: (_) => screen));
  }

  Widget _menu(
    String icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DesignIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: profileText(16, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: profileText(12, color: AppColors.greyText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const DesignIcon(
              'profile_chevron',
              size: 16,
              color: AppColors.greyText,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final profile = controller.profile;
      final edit = controller.queuedProfileEdit;
      final hasProfile = profile != null || edit != null;
      final name = edit?.name ?? profile?.fullName ?? '';
      final email = edit?.email ?? profile?.email ?? '';
      final notice = controller.profileNotice;
      return ProfilePage(
        title: 'My profile',
        gap: 33,
        onNavTap: widget.onNavTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.loading && !hasProfile)
              const Center(child: CircularProgressIndicator()),
            if (notice != null) ...[
              ProfileNotice(
                notice,
                onRetry: controller.loading ? null : controller.load,
              ),
              const SizedBox(height: 16),
            ],
            if (controller.error != null) ...[
              ProfileError(controller.error!),
              const SizedBox(height: 16),
              ProfileButton(text: 'Try again', onPressed: controller.load),
              const SizedBox(height: 16),
            ],
            if (hasProfile) ...[
              ProfileCard(
                color: AppColors.lightPurple,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const DesignIcon('profile_user', size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name.isEmpty ? 'My profile' : name,
                      style: profileText(25, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      email,
                      style: profileText(13, color: AppColors.greyText),
                    ),
                    const SizedBox(height: 12),
                    ProfileButton(
                      text: 'Edit profile',
                      onPressed: () => _open(
                        'edit_profile',
                        EditProfileScreen(
                          controller: controller,
                          onNavTap: widget.onNavTap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _menu(
                'profile_car',
                'My vehicles',
                'Add your car or motorcycle plate',
                () => _open(
                  'vehicles',
                  VehiclesScreen(
                    controller: controller,
                    onNavTap: widget.onNavTap,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _menu(
                'profile_clock',
                'My parking',
                'Check your parking and pickup time',
                widget.onMyParking,
              ),
              const SizedBox(height: 16),
              if (widget.onParkingHistory != null) ...[
                _menu(
                  'profile_clock',
                  'Saved parking',
                  'Completed stays on this device',
                  widget.onParkingHistory!,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.onLastParkingSummary != null) ...[
                _menu(
                  'profile_clock',
                  'Last parking summary',
                  'View your last completed parking stay',
                  widget.onLastParkingSummary!,
                ),
                const SizedBox(height: 16),
              ],
              _menu(
                'profile_heart',
                'My favorites',
                'Your saved parking lots',
                () => widget.onNavTap(2),
              ),
              const SizedBox(height: 16),

              if (controller.isAdmin) ...[
                _menu(
                  'profile_clock',
                  'Analytics dashboard',
                  'Open shared metrics in your browser',
                  widget.onAnalyticsDashboard,
                ),

                const SizedBox(height: 16),
              ],
              Text(
                'Everything you need to get to campus and back.',
                style: profileText(13, color: AppColors.greyText),
              ),
              const SizedBox(height: 16),
              ProfileButton(
                text: controller.busy ? 'Signing out...' : 'Sign out',
                background: Colors.white,
                foreground: AppColors.primary,
                onPressed: controller.busy
                    ? null
                    : () async {
                        await widget.onSigningOut?.call();
                        if (!mounted) return;
                        if (await controller.signOut() && mounted) {
                          widget.onSignedOut();
                        }
                      },
              ),
            ],
            if ((profile == null || controller.loading) &&
                widget.onLastParkingSummary != null) ...[
              _menu(
                'profile_clock',
                'Last parking summary',
                'View your saved parking summary',
                widget.onLastParkingSummary!,
              ),
              const SizedBox(height: 16),
            ],
            if ((profile == null || controller.loading) &&
                widget.onParkingHistory != null)
              _menu(
                'profile_clock',
                'Saved parking',
                'Completed stays on this device',
                widget.onParkingHistory!,
              ),
          ],
        ),
      );
    },
  );
}
