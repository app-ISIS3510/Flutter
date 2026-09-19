import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';

class EndParkingScreen extends StatelessWidget {
  final VoidCallback onConfirmEndParking;
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const EndParkingScreen({
    super.key,
    required this.onConfirmEndParking,
    required this.currentIndex,
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 22, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End parking',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 90),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_parking_outlined,
                            size: 52,
                            color: AppColors.primary,
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Have you picked up\nyour vehicle?',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'Confirm to end this parking stay and stop the countdown.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: AppColors.greyText,
                            ),
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                onConfirmEndParking();
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                "Yes, I've picked it up",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.lightPurple,
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Not yet, go back',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            NavBar(
              currentIndex: currentIndex,
              onTap: (index) {
                Navigator.pop(context);
                onNavTap(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}