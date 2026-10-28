class MostUsedParking {
  final String parkingId;
  final String parkingName;
  final int completedSessions;

  const MostUsedParking({
    required this.parkingId,
    required this.parkingName,
    required this.completedSessions,
  });

  factory MostUsedParking.fromMap(Map<String, dynamic> map) {
    return MostUsedParking(
      parkingId: map['parking_id'] as String,
      parkingName: map['parking_name'] as String,
      completedSessions: (map['completed_sessions'] as num).toInt(),
    );
  }
}
