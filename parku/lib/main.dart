import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const ParkUApp());
}

class ParkUApp extends StatelessWidget {
  const ParkUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ParkU',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter',
      ),
      home: const MainNavigationScreen(),
    );
  }
}