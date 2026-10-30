import 'navigation_adapter.dart';

class GoogleMapsAdapter implements NavigationAdapter {
  @override
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  }) {
    return launchNavigationLinks(
      appUri: Uri.parse('google.navigation:q=$latitude,$longitude&mode=d'),
      webUri: Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      }),
    );
  }
}
