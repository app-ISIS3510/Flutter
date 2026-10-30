import 'dart:convert';

class PendingAnalyticsEvent {
  final String id;
  final String userId;
  final String eventType;
  final String? screen;
  final String? parkingId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final int attempts;

  const PendingAnalyticsEvent({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
    this.screen,
    this.parkingId,
    this.attempts = 0,
  });

  Map<String, dynamic> get payload => {
    'id': id,
    'user_id': userId,
    'event_type': eventType,
    'screen': screen,
    'parking_id': parkingId,
    'metadata': metadata,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toLocalMap() => {
    'id': id,
    'user_id': userId,
    'payload': jsonEncode(payload),
    'created_at_ms': createdAt.millisecondsSinceEpoch,
    'attempt_count': attempts,
    'next_attempt_ms': 0,
  };

  factory PendingAnalyticsEvent.fromLocalMap(Map<String, Object?> row) {
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    return PendingAnalyticsEvent(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      eventType: payload['event_type'] as String,
      screen: payload['screen'] as String?,
      parkingId: payload['parking_id'] as String?,
      metadata: Map<String, dynamic>.from(payload['metadata'] as Map),
      createdAt: DateTime.parse(payload['created_at'] as String),
      attempts: row['attempt_count'] as int,
    );
  }
}
