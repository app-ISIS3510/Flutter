import '../models/parking.dart';

class ParkingListState {
  final List<Parking>? parkingLots;
  final DateTime? updatedAt;
  final bool isFromCache;
  final bool isRefreshing;
  final String? errorMessage;

  const ParkingListState({
    this.parkingLots,
    this.updatedAt,
    this.isFromCache = false,
    this.isRefreshing = false,
    this.errorMessage,
  });

  bool get hasData => parkingLots != null;
}