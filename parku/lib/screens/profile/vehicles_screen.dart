import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/design_icon.dart';
import 'add_vehicle_screen.dart';
import 'driving_restrictions_screen.dart';
import 'profile_widgets.dart';

class VehiclesScreen extends StatelessWidget {
  final ProfileController controller;
  final ValueChanged<int> onNavTap;
  final bool choosingVehicle;
  const VehiclesScreen({
    super.key,
    required this.controller,
    required this.onNavTap,
    this.choosingVehicle = false,
  });

  void _add(BuildContext context) {
    controller.clearError();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            AddVehicleScreen(controller: controller, onNavTap: onNavTap),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${vehicle.plate}?'),
        content: const Text('You can add this vehicle again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteVehicle(vehicle.id);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final empty = controller.vehicles.isEmpty;
      return ProfilePage(
        title: 'My vehicles',
        onBack: () => Navigator.pop(context),
        onNavTap: onNavTap,
        gap: empty ? 70 : 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (controller.error != null) ...[
                ProfileError(controller.error!),
                const SizedBox(height: 16),
                ProfileButton(
                  text: 'Refresh vehicles',
                  onPressed: controller.busy ? null : controller.load,
                ),
                const SizedBox(height: 16),
              ],
              if (empty) ...[
                ProfileCard(
                  color: AppColors.lightPurple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DesignIcon('empty_car', size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Add your first vehicle',
                        style: profileText(25, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Save your car or motorcycle plate to track your parking and check driving restrictions.',
                        style: profileText(16, color: AppColors.greyText),
                      ),
                      const SizedBox(height: 12),
                      ProfileButton(
                        text: 'Add vehicle',
                        onPressed: () => _add(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ProfileButton(
                  text: 'Back to profile',
                  background: Colors.white,
                  foreground: AppColors.primary,
                  onPressed: () => Navigator.pop(context),
                ),
              ] else ...[
                Text(
                  'Choose the vehicle you want to use.',
                  style: profileText(15, color: AppColors.greyText),
                ),
                const SizedBox(height: 16),
                for (final vehicle in controller.vehicles) ...[
                  ProfileCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (vehicle.type == VehicleType.car)
                              const DesignIcon('profile_car')
                            else
                              const Icon(
                                Icons.two_wheeler_outlined,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            const SizedBox(width: 12),
                            Text(
                              vehicle.type.label,
                              style: profileText(18, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          vehicle.plate,
                          style: profileText(25, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 192,
                              child: Semantics(
                                selected: vehicle.isSelected,
                                child: ProfileButton(
                                  text: 'Use vehicle',
                                  height: 44,
                                  background: AppColors.lightPurple,
                                  foreground: AppColors.primary,
                                  onPressed: controller.busy
                                      ? null
                                      : () async {
                                          if (!await controller.selectVehicle(
                                                vehicle.id,
                                              ) ||
                                              !context.mounted) {
                                            return;
                                          }
                                          if (choosingVehicle) {
                                            Navigator.pop(
                                              context,
                                              controller.selectedVehicle,
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${vehicle.plate} selected for your next parking stay.',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 110,
                              child: ProfileButton(
                                text: 'Delete',
                                height: 44,
                                background: Colors.white,
                                foreground: AppColors.primary,
                                onPressed: controller.busy
                                    ? null
                                    : () => _delete(context, vehicle),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ProfileButton(
                  text: 'Add vehicle',
                  onPressed: controller.busy ? null : () => _add(context),
                ),
                const SizedBox(height: 16),
                ProfileButton(
                  text: 'Check driving restrictions',
                  background: Colors.white,
                  foreground: AppColors.primary,
                  onPressed: controller.selectedVehicle == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => DrivingRestrictionsScreen(
                                controller: controller,
                                onNavTap: onNavTap,
                              ),
                            ),
                          );
                        },
                ),
                const SizedBox(height: 16),
                Text(
                  'Vehicle for your next parking stay',
                  style: profileText(12, color: AppColors.greyText),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}
