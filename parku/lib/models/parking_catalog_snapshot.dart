import 'parking.dart';

class ParkingCatalogSnapshot {
  final List<Parking> parkingLots;
  final DateTime updatedAt;
  final bool isFromCache;

  const ParkingCatalogSnapshot({
    required this.parkingLots,
    required this.updatedAt,
    this.isFromCache = false,
  });
}
