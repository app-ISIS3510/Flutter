class ParkingSession {
  final String id;
  final String? userId;
  final String parkingId;
  final DateTime pickupTime;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status;
  final String vehicleType;
  final String? vehicleId;
  final String? vehiclePlate;
  final bool isFromCache;
  final DateTime? confirmedAt;

  ParkingSession({
    required this.id,
    this.userId,
    required this.parkingId,
    required this.pickupTime,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.vehicleType = 'car',
    this.vehicleId,
    this.vehiclePlate,
    this.isFromCache = false,
    this.confirmedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'parking_id': parkingId,
    'pickup_time': pickupTime.toUtc().toIso8601String(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'status': status,
    'vehicle_type': vehicleType,
    'vehicle_id': vehicleId,
    'vehicle_plate': vehiclePlate,
  };

  factory ParkingSession.fromMap(
    Map<String, dynamic> map, {
    bool isFromCache = false,
    DateTime? confirmedAt,
  }) {
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
      vehicleType: map['vehicle_type'] as String? ?? 'car',
      vehicleId: map['vehicle_id'] as String?,
      vehiclePlate: map['vehicle_plate'] as String?,
      isFromCache: isFromCache,
      confirmedAt: confirmedAt,
    );
  }
}
