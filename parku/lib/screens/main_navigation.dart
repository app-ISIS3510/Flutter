import 'package:flutter/material.dart';

import 'parking_list.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int currentIndex = 0;

  void changePage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return MapScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
        );

      case 1:
        return ParkingListScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
        );

      default:
        return MapScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
        );
    }
  }
}