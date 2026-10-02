import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/profile_controller.dart';
import '../../models/vehicle.dart';
import '../../services/driving_restriction_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/design_icon.dart';
import 'profile_widgets.dart';
import 'vehicles_screen.dart';

class DrivingRestrictionsScreen extends StatefulWidget {
  final ProfileController controller;
  final ValueChanged<int> onNavTap;
  final DateTime? now;
  const DrivingRestrictionsScreen({
    super.key,
    required this.controller,
    required this.onNavTap,
    this.now,
  });
  @override
  State<DrivingRestrictionsScreen> createState() =>
      _DrivingRestrictionsScreenState();
}

class _DrivingRestrictionsScreenState extends State<DrivingRestrictionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  String _date(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return 'Bogotá · ${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  Future<void> _officialInfo() async {
    try {
      if (await launchUrl(
        Uri.parse(DrivingRestrictionService.officialUrl),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      /* Se muestra el mismo mensaje si no hay navegador disponible. */
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the official website. Please try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final vehicle = widget.controller.selectedVehicle;
      final restriction = widget.controller.drivingRestriction(now: widget.now);
      final restricted = restriction?.restricted;
      final color = restricted == false
          ? const Color(0xFF16704A)
          : const Color(0xFFA3313F);
      return ProfilePage(
        title: 'Driving restrictions',
        gap: 36,
        onBack: () => Navigator.pop(context),
        onNavTap: widget.onNavTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicle == null)
              const ProfileError(
                'Select a vehicle to check driving restrictions.',
              )
            else ...[
              Text(
                _date(restriction!.date),
                style: profileText(14, color: AppColors.greyText),
              ),
              const SizedBox(height: 16),
              ProfileCard(
                color: restricted == false
                    ? const Color(0xFFE8F6EE)
                    : const Color(0xFFFCECF0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DesignIcon(
                      restricted == false
                          ? 'restriction_check'
                          : 'restriction_alert',
                      size: 40,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      restricted == null
                          ? 'Check today’s restrictions'
                          : restricted
                          ? 'Driving restrictions apply today'
                          : 'No driving restrictions today',
                      style: profileText(
                        26,
                        weight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(vehicle.type.label, style: profileText(16)),
                        Text(
                          vehicle.plate,
                          style: profileText(20, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (restriction.hours != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Restricted: ${restriction.hours}',
                        style: profileText(
                          14,
                          weight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                restriction.explanation ?? 'Restrictions depend on your vehicle type, license plate and date.',
                style: profileText(15, color: AppColors.greyText),
              ),
            ],
            const SizedBox(height: 16),
            ProfileButton(
              text: 'View official information',
              background: AppColors.lightPurple,
              foreground: AppColors.primary,
              onPressed: _officialInfo,
            ),
            const SizedBox(height: 16),
            ProfileButton(
              text: 'Change vehicle',
              background: Colors.white,
              foreground: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<Vehicle>(
                  builder: (_) => VehiclesScreen(
                    controller: widget.controller,
                    onNavTap: widget.onNavTap,
                    choosingVehicle: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
