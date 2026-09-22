import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  

  await Supabase.initialize(
    url: 'https://wwvkgpstphxeldscncyf.supabase.co',
    publishableKey: 'sb_publishable_i7kN0azgQ2JYTD1bm33ZFA_c6mLTnjN',
  );

  print(Supabase.instance.client);

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