import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/design_icon.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/pickup_widgets.dart';

class PickupTimeScreen extends StatefulWidget {
  final ValueChanged<int> onNavTap;
  final ValueChanged<String> onStartParking;

  const PickupTimeScreen({
    super.key,
    required this.onNavTap,
    required this.onStartParking,
  });

  @override
  State<PickupTimeScreen> createState() => _PickupTimeScreenState();
}

class _PickupTimeScreenState extends State<PickupTimeScreen> {
  // Solo cambia la maqueta; no se guarda en un servidor.
  String selectedTime = '4:00';

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
                    ScreenHeader(
                      title: 'Pickup time',
                      onBack: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'When will you pick it up?',
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose an approximate time to pick up your vehicle.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              DesignIcon('car'),
                              SizedBox(width: 10),
                              Text(
                                'Car',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ABC123',
                            style: TextStyle(
                              fontSize: 22,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PickupButton(
                            text: 'Change vehicle',
                            background: AppColors.white,
                            foreground: AppColors.primary,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Demo vehicle: Car · ABC123'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Today · Pickup time',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DesignIcon('clock', size: 28),
                          const SizedBox(width: 12),
                          Text(
                            '$selectedTime PM',
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SuggestedTimes(
                      selectedTime: selectedTime,
                      onChanged: (time) => setState(() => selectedTime = time),
                    ),
                    const SizedBox(height: 16),
                    PickupButton(
                      text: 'Start parking',
                      onPressed: () => widget.onStartParking(selectedTime),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You can change this time whenever you need.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.greyText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            NavBar(currentIndex: 1, onTap: widget.onNavTap),
          ],
        ),
      ),
    );
  }
}
