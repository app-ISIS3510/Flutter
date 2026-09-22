import 'package:url_launcher/url_launcher.dart';

import 'navigation_adapter.dart';

class GoogleMapsAdapter implements NavigationAdapter {
  @override
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude',
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception('Could not open Google Maps');
    }
  }
}