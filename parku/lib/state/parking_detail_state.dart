import '../models/parking.dart';
import '../models/parking_availability.dart';

class ParkingDetailState {
  final Parking? parking;
  final DateTime? updatedAt;
  final bool isFromCache;
  final bool isFromMemory;
  final String? errorMessage;

  const ParkingDetailState({
    this.parking,
    this.updatedAt,
    this.isFromCache = false,
    this.isFromMemory = false,
    this.errorMessage,
  });

  ParkingAvailability? get availability => parking == null
      ? null
      : ParkingAvailability(
          parking: parking!,
          updatedAt: updatedAt,
          isFromCache: isFromCache,
        );
}
