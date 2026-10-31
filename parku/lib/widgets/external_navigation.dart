import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/navigation_controller.dart';
import '../controllers/analytics_controller.dart';
import '../models/navigation_provider.dart';
import '../models/parking.dart';
import '../theme/app_theme.dart';
import 'user_error_notice.dart';
import '../utils/client_id.dart';

/// Returns the provider whose link was accepted by the operating system.
/// Opening a link does not guarantee that the provider can calculate a route.
Future<NavigationProvider?> openExternalNavigation({
  required BuildContext context,
  required NavigationController controller,
  required NavigationProvider provider,
  required Parking parking,
  AnalyticsController? analytics,
  String screen = 'parking_detail',
  String? activeSessionId,
}) async {
  final analyticsOwner = analytics?.currentUserId;
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
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.cloud_off_rounded, color: AppColors.primary),
        title: Text(
          hasNetwork == false ? "You're offline" : 'Connection unavailable',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${provider.label} may need internet for directions.'),
              if (parking.name.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  parking.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _copyLocation(dialogContext, location),
            child: const Text('Copy location'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            ),
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
      final requestedAt = DateTime.now().toUtc();
      await controller.openNavigation(
        provider: selectedProvider,
        latitude: latitude!,
        longitude: longitude!,
      );
      if (analytics != null &&
          analyticsOwner != null &&
          analytics.currentUserId == analyticsOwner) {
        // Preserve the handoff time even when enrichment or offline sync is late.
        // Telemetry failures must never turn a successful launch into a retry.
        unawaited(
          Future<void>.sync(
            () => analytics.track(
              eventType: 'navigation_opened',
              screen: screen,
              parkingId: parking.id,
              occurredAt: requestedAt,
              metadata: {
                'event_schema_version': 2,
                'navigation_request_id': newClientId(),
                'provider': selectedProvider.analyticsValue,
                'requested_provider': provider.analyticsValue,
                'used_fallback': selectedProvider != provider,
                'active_session_id': ?activeSessionId,
              },
            ),
          ).catchError((Object error, StackTrace stackTrace) {
            developer.log(
              'Could not queue navigation analytics',
              error: error,
              stackTrace: stackTrace,
            );
          }),
        );
      }
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
            'Try ${selectedProvider.alternative.label} or copy the location.',
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
    showUserInfo(context, 'Location copied.', icon: Icons.check_circle_outline);
  } catch (_) {
    if (!context.mounted) return;
    showUserMessage(context, 'Could not copy. Select the location text.');
  }
}
