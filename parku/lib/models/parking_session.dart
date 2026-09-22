class ParkingSession {
  final String id;
  final String? userId;
  final String parkingId;
  final DateTime pickupTime;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;

  ParkingSession({
    required this.id,
    this.userId,
    required this.parkingId,
    required this.pickupTime,
    required this.startedAt,
    this.endedAt,
    required this.status,
  });

  factory ParkingSession.fromMap(Map<String, dynamic> map) {
    return ParkingSession(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      parkingId: map['parking_id'] as String,
      pickupTime: DateTime.parse(map['pickup_time'] as String),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      status: map['status'] as String,
    );
  }
}