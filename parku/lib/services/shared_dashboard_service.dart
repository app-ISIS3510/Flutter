import 'package:url_launcher/url_launcher.dart';

class SharedDashboardService {
  static final reportUri = Uri.parse(
    'https://datastudio.google.com/reporting/'
    'bfb7149e-1f1b-44d1-a6c7-37117ca2143a/page/9u6BG',
  );

  Future<void> open() async {
    final opened = await launchUrl(
      reportUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw StateError('Could not open the shared dashboard.');
    }
  }
}
