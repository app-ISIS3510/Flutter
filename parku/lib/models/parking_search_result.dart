import 'parking.dart';

class ParkingSearchResult {
  final List<Parking> parkingLots;
  final bool isFromCache;
  final DateTime? updatedAt;

  const ParkingSearchResult({
    required this.parkingLots,
    this.isFromCache = false,
    this.updatedAt,
  });
}
