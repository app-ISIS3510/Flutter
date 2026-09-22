import 'package:url_launcher/url_launcher.dart';

import 'navigation_adapter.dart';

class WazeAdapter implements NavigationAdapter {
  @override
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not open Waze');
    }
  }
}