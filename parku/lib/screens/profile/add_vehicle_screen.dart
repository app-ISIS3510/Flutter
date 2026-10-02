import 'package:flutter/material.dart';

import '../../controllers/profile_controller.dart';
import '../../models/vehicle.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import 'profile_widgets.dart';

class AddVehicleScreen extends StatefulWidget {
  final ProfileController controller;
  final ValueChanged<int> onNavTap;
  const AddVehicleScreen({
    super.key,
    required this.controller,
    required this.onNavTap,
  });
  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plate = TextEditingController();
  VehicleType _type = VehicleType.car;
  String? _validationError;
  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(
      () => _validationError = ProfileService.validatePlate(_type, _plate.text),
    );
    if (_validationError != null) return;
    FocusScope.of(context).unfocus();
    if (await widget.controller.addVehicle(_type, _plate.text) && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => ProfilePage(
      title: 'Add vehicle',
      gap: 28,
      onBack: () => Navigator.pop(context),
      onNavTap: widget.onNavTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you drive?',
            style: profileText(22, weight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter your license plate to identify your vehicle.',
            style: profileText(14, color: AppColors.greyText),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final type in VehicleType.values) ...[
                if (type == VehicleType.motorcycle) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    selected: type == _type,
                    child: ProfileButton(
                      text: type.label,
                      background: type == _type
                          ? AppColors.lightPurple
                          : Colors.white,
                      foreground: AppColors.primary,
                      onPressed: widget.controller.busy
                          ? null
                          : () {
                              setState(() {
                                _type = type;
                                _validationError = null;
                              });
                            },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          ProfileField(
            label: 'License plate',
            hint: 'Enter license plate',
            controller: _plate,
            enabled: !widget.controller.busy,
            capitalization: TextCapitalization.characters,
            onChanged: (_) {
              if (_validationError != null) {
                setState(() => _validationError = null);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Example: ${_type == VehicleType.car ? 'ABC123' : 'ABC12D'} · No spaces or hyphens.',
            style: profileText(12, color: AppColors.greyText),
          ),
          const SizedBox(height: 16),
          if (_validationError != null || widget.controller.error != null) ...[
            ProfileError(_validationError ?? widget.controller.error!),
            const SizedBox(height: 16),
          ],
          ProfileCard(
            color: AppColors.lightPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your vehicle, connected',
                  style: profileText(17, weight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  'We use your plate to identify your parking stay and show driving restrictions in Bogotá.',
                  style: profileText(14, color: AppColors.greyText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProfileButton(
            text: widget.controller.busy ? 'Saving...' : 'Save vehicle',
            onPressed: widget.controller.busy ? null : _save,
          ),
          const SizedBox(height: 16),
          ProfileButton(
            text: 'Cancel',
            background: Colors.white,
            foreground: AppColors.primary,
            onPressed: widget.controller.busy
                ? null
                : () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
