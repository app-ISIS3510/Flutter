import 'most_used_parking.dart';

class MostUsedParkingRanking {
  final List<MostUsedParking> parkingLots;
  final DateTime updatedAt;
  final bool isFromCache;

  const MostUsedParkingRanking({
    required this.parkingLots,
    required this.updatedAt,
    this.isFromCache = false,
  });

  factory MostUsedParkingRanking.fromMap(Map<String, dynamic> data) {
    final parkingLots = (data['parking_lots'] as List)
        .map((row) => MostUsedParking.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    if (parkingLots.length > 3 ||
        parkingLots.map((lot) => lot.parkingId).toSet().length !=
            parkingLots.length) {
      throw const FormatException('Invalid saved parking ranking.');
    }
    return MostUsedParkingRanking(
      parkingLots: parkingLots,
      updatedAt: DateTime.parse(data['updated_at'] as String),
      isFromCache: true,
    );
  }

  Map<String, dynamic> toMap() => {
    'parking_lots': parkingLots.map((lot) => lot.toMap()).toList(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
