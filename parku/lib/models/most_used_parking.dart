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
    final sessions = map['completed_sessions'];
    if (map['parking_id'] is! String ||
        (map['parking_id'] as String).trim().isEmpty ||
        map['parking_name'] is! String ||
        (map['parking_name'] as String).trim().isEmpty ||
        sessions is! num ||
        !sessions.isFinite ||
        sessions < 0 ||
        sessions != sessions.toInt()) {
      throw const FormatException('Invalid parking ranking.');
    }
    return MostUsedParking(
      parkingId: map['parking_id'] as String,
      parkingName: map['parking_name'] as String,
      completedSessions: sessions.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    'parking_id': parkingId,
    'parking_name': parkingName,
    'completed_sessions': completedSessions,
  };
}
