import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'utils/app_error_handler.dart';
import 'widgets/unexpected_error_view.dart';
import 'widgets/connectivity_banner.dart';
import 'services/profile_service.dart';
import 'services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.install();

  try {
    await Supabase.initialize(
      url: 'https://wwvkgpstphxeldscncyf.supabase.co',
      publishableKey: 'sb_publishable_i7kN0azgQ2JYTD1bm33ZFA_c6mLTnjN',
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace),
    );
    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: UnexpectedErrorView(duringStartup: true),
      ),
    );
    return;
  }

  runApp(const ParkUApp());
}

class ParkUApp extends StatelessWidget {
  final ProfileService? profileService;
  final SessionService? sessionService;
  const ParkUApp({super.key, this.profileService, this.sessionService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: AppErrorHandler.messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'ParkU',
      builder: (context, child) =>
          ConnectivityBanner(child: child ?? const SizedBox.shrink()),
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
