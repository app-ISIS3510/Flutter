import 'parking_session.dart';

class ParkingSummary {
  final String sessionId;
  final String userId;
  final String parkingId;
  final String parkingName;
  final String? parkingAddress;
  final num? pricePerMinute;
  final String vehicleType;
  final String? vehiclePlate;
  final DateTime startedAt;
  final DateTime pickupTime;
  final DateTime endedAt;

  const ParkingSummary({
    required this.sessionId,
    required this.userId,
    required this.parkingId,
    required this.parkingName,
    this.parkingAddress,
    this.pricePerMinute,
    required this.vehicleType,
    this.vehiclePlate,
    required this.startedAt,
    required this.pickupTime,
    required this.endedAt,
  });

  int get durationMinutes {
    final minutes = endedAt.difference(startedAt).inMinutes;
    return minutes < 1 ? 1 : minutes;
  }

  num? get totalCost {
    final rate = pricePerMinute;

    if (rate == null) return null;

    return durationMinutes * rate;
  }

  factory ParkingSummary.fromSession(
    ParkingSession session, {
    required String parkingName,
    String? parkingAddress,
    num? pricePerMinute,
  }) {
    if (session.status != 'completed' ||
        session.endedAt == null ||
        session.userId == null) {
      throw ArgumentError(
        'Only confirmed completed sessions can be saved.',
      );
    }

    return ParkingSummary(
      sessionId: session.id,
      userId: session.userId!,
      parkingId: session.parkingId,
      parkingName: parkingName,
      parkingAddress: parkingAddress,
      pricePerMinute: pricePerMinute,
      vehicleType: session.vehicleType,
      vehiclePlate: session.vehiclePlate,
      startedAt: session.startedAt,
      pickupTime: session.pickupTime,
      endedAt: session.endedAt!,
    );
  }

  factory ParkingSummary.fromMap(Map<String, dynamic> map) {
    return ParkingSummary(
      sessionId: map['session_id'] as String,
      userId: map['user_id'] as String,
      parkingId: map['parking_id'] as String,
      parkingName: map['parking_name'] as String,
      parkingAddress: map['parking_address'] as String?,
      pricePerMinute: map['price_per_minute'] as num?,
      vehicleType: map['vehicle_type'] as String,
      vehiclePlate: map['vehicle_plate'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      pickupTime: DateTime.parse(map['pickup_time'] as String),
      endedAt: DateTime.parse(map['ended_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'parking_id': parkingId,
      'parking_name': parkingName,
      'parking_address': parkingAddress,
      'price_per_minute': pricePerMinute,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'started_at': startedAt.toUtc().toIso8601String(),
      'pickup_time': pickupTime.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
    };
  }
}