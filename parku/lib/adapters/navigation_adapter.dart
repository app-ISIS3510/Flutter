import 'dart:developer' as developer;

import 'package:url_launcher/url_launcher.dart';

abstract class NavigationAdapter {
  Future<void> openNavigation({
    required double latitude,
    required double longitude,
  });
}

Future<void> launchNavigationLinks({
  required Uri appUri,
  required Uri webUri,
}) async {
  for (final uri in [appUri, webUri]) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (error, stackTrace) {
      developer.log(
        'Could not open navigation link (${uri.scheme})',
        name: 'NavigationAdapter',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  throw StateError('Could not open the navigation app or its web link.');
}
