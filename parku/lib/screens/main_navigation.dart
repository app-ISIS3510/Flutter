import 'package:flutter/material.dart';

import 'home.dart';
import 'parking_list.dart';
import 'my_parking.dart';
import 'no_active_parking.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {

  int currentIndex = 0;

  // POR DEFAULT NO HAY PARQUEO
  bool hasActiveParking = true;

  void changePage(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  void startParking() {
    setState(() {
      hasActiveParking = true;
      currentIndex = 3;
    });
  }

  void endParking() {
    setState(() {
      hasActiveParking = false;
    });
  }

  void openMyParking() {
    setState(() {
      currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return HomeScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          hasActiveParking: hasActiveParking,
          onOpenMyParking: openMyParking,
        );

      case 1:
        return ParkingListScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
        );

      case 3:
        if (hasActiveParking) {
          return MyParkingScreen(
            currentIndex: currentIndex,
            onNavTap: changePage,
            onEndParking: endParking,
          );
        } else {
          return NoActiveParkingScreen(
            currentIndex: currentIndex,
            onNavTap: changePage,
          );
        }

      default:
        return HomeScreen(
          currentIndex: currentIndex,
          onNavTap: changePage,
          hasActiveParking: hasActiveParking,
          onOpenMyParking: openMyParking,
        );
    }
  }
}