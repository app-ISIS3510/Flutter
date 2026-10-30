import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';

class NoActiveParkingScreen extends StatelessWidget {
  final bool isFromCache;
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const NoActiveParkingScreen({
    super.key,
    this.isFromCache = false,
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 22, 30, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My parking',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),

                    const SizedBox(height: 110),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurple,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.local_parking_outlined,
                            color: AppColors.primary,
                            size: 54,
                          ),

                          const SizedBox(height: 20),

                          Text(
                            isFromCache
                                ? 'No active parking saved'
                                : 'No active parking',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            isFromCache
                                ? 'The last saved snapshot had no active session. '
                                      'Reconnect to check your current server status.'
                                : 'Start parking after you leave your vehicle to see how much time is left until pickup.',
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: AppColors.greyText,
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // Parking lots
                                onNavTap(1);
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
                                'Find parking',
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

            NavBar(currentIndex: currentIndex, onTap: onNavTap),
          ],
        ),
      ),
    );
  }
}
