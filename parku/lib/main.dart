import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'services/profile_service.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wwvkgpstphxeldscncyf.supabase.co',
    publishableKey: 'sb_publishable_i7kN0azgQ2JYTD1bm33ZFA_c6mLTnjN',
  );

  runApp(const ParkUApp());
}

class ParkUApp extends StatelessWidget {
  final ProfileService? profileService;
  final SessionService? sessionService;
  const ParkUApp({super.key, this.profileService, this.sessionService});

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
      home: AuthGate(
        profileService: profileService,
        sessionService: sessionService,
      ),
    );
  }
}
