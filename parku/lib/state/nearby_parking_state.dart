import '../models/parking_option.dart';

class NearbyParkingState {
  final List<ParkingOption> options;
  final DateTime? updatedAt;
  final bool isFromCache;
  final bool isLocating;
  final String? locationNotice;
  final String? errorMessage;

  const NearbyParkingState({
    this.options = const [],
    this.updatedAt,
    this.isFromCache = false,
    this.isLocating = false,
    this.locationNotice,
    this.errorMessage,
  });
}
