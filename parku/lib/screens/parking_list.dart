import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/navigation_bar.dart';

class ParkingListScreen extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  const ParkingListScreen({
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
            const Padding(
              padding: EdgeInsets.all(32),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Parking lots',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

            const Expanded(
              child: Center(
                child: Text(
                  'Parking lots screen',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ),

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