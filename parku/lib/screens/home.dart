import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';

class HomeScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const HomeScreen({
    super.key,
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
            // HEADER
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 22, 32, 22),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ParkU',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

            // MAP
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/map.png',
                      fit: BoxFit.cover,
                    ),
                  ),

                  // LOCATION BOX
                  Positioned(
                    top: 20,
                    left: 30,
                    right: 30,
                    child: Container(
                      height: 72,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Near Universidad de los Andes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // PARKING MARKERS
                  const Positioned(
                    top: 160,
                    left: 210,
                    child: ParkingMarker(),
                  ),

                  const Positioned(
                    top: 270,
                    right: 100,
                    child: ParkingMarker(),
                  ),

                  const Positioned(
                    top: 310,
                    left: 120,
                    child: ParkingMarker(),
                  ),

                  // MY PARKING CARD
                  Positioned(
                    left: 30,
                    right: 30,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lightPurple,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text(
                              'MY PARKING',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          const Text(
                            'No active parking',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Your current parking will appear here.',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.greyText,
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'My parking',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

           BottomNavBar(
            currentIndex: currentIndex,
            onTap: onNavTap,
          ),
          ],
        ),
      ),
    );
  }
}

class ParkingMarker extends StatelessWidget {
  const ParkingMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.location_on_outlined,
          color: AppColors.primary,
          size: 34,
        ),
      ),
    );
  }
}