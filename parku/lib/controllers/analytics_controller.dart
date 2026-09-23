import '../services/analytics_service.dart';

class AnalyticsController {
  final AnalyticsService service;

  AnalyticsController(this.service);

  Future<void> track({
    required String eventType,
    String? screen,
    String? parkingId,
    Map<String, dynamic>? metadata,
  }) {
    return service.track(
      eventType: eventType,
      screen: screen,
      parkingId: parkingId,
      metadata: metadata,
    );
  }
}