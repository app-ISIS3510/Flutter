import 'navigation_adapter.dart';

class WazeAdapter implements NavigationAdapter {
  @override
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  }) {
    return launchNavigationLinks(
      appUri: Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes'),
      webUri: Uri.https('waze.com', '/ul', {
        'll': '$latitude,$longitude',
        'navigate': 'yes',
        'utm_source': 'parku',
      }),
    );
  }
}
