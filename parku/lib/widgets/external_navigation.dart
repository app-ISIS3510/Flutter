import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/navigation_controller.dart';
import '../models/navigation_provider.dart';
import '../models/parking.dart';

/// Returns the provider whose link was accepted by the operating system.
/// Opening a link does not guarantee that the provider can calculate a route.
Future<NavigationProvider?> openExternalNavigation({
  required BuildContext context,
  required NavigationController controller,
  required NavigationProvider provider,
  required Parking parking,
}) async {
  final latitude = parking.latitude;
  final longitude = parking.longitude;
  final hasCoordinates = controller.hasValidCoordinates(latitude, longitude);
  final location = [
    if (parking.name.trim().isNotEmpty) parking.name,
    if (parking.address.trim().isNotEmpty) parking.address,
    if (hasCoordinates) '$latitude, $longitude',
  ].join('\n');

  if (!hasCoordinates) {
    await _showFallback(
      context,
      title: 'Parking location is not available',
      message: 'You can use the saved address in another navigation app.',
      location: location,
    );
    return null;
  }

  final hasNetwork = await controller.checkNetworkConnection();
  if (!context.mounted) return null;

  if (hasNetwork != true) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hasNetwork == false
              ? 'No network connection detected'
              : 'Could not check the connection',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${provider.label} may need Internet to load maps or calculate '
                'a route. Offline navigation depends on the maps and routes '
                'already saved in that app.',
              ),
              const SizedBox(height: 16),
              SelectableText(location),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay here'),
          ),
          TextButton(
            onPressed: () => _copyLocation(dialogContext, location),
            child: const Text('Copy location'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open anyway'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return null;
  }

  var selectedProvider = provider;
  while (context.mounted) {
    try {
      await controller.openNavigation(
        provider: selectedProvider,
        latitude: latitude!,
        longitude: longitude!,
      );
      return selectedProvider;
    } catch (error, stackTrace) {
      developer.log(
        'Could not open ${selectedProvider.label}',
        name: 'ExternalNavigation',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return null;
      final alternative = await _showFallback(
        context,
        title: 'Could not open ${selectedProvider.label}',
        message:
            'Try another navigation app, or copy the saved location '
            'to use it later. Maps and routes may require Internet.',
        location: location,
        alternative: selectedProvider.alternative,
      );
      if (alternative == null || !context.mounted) return null;
      selectedProvider = alternative;
    }
  }
  return null;
}

Future<NavigationProvider?> _showFallback(
  BuildContext context, {
  required String title,
  required String message,
  required String location,
  NavigationProvider? alternative,
}) {
  return showDialog<NavigationProvider>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 16),
              SelectableText(location),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        if (location.isNotEmpty)
          TextButton(
            onPressed: () => _copyLocation(dialogContext, location),
            child: const Text('Copy location'),
          ),
        if (alternative != null)
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, alternative),
            child: Text('Try ${alternative.label}'),
          ),
      ],
    ),
  );
}

Future<void> _copyLocation(BuildContext context, String location) async {
  try {
    await Clipboard.setData(ClipboardData(text: location));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Location copied.')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not copy. Select the location text.'),
      ),
    );
  }
}
