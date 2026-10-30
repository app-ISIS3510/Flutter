import 'parking.dart';
import 'vehicle.dart';
import 'parking_availability.dart';

class ParkingOption {
  final Parking parking;
  final double distanceMeters;
  final VehicleType? vehicleType;
  final bool isFromCache;
  final DateTime? updatedAt;

  const ParkingOption({
    required this.parking,
    required this.distanceMeters,
    this.vehicleType,
    this.isFromCache = false,
    this.updatedAt,
  });

  ParkingAvailability get availability => ParkingAvailability(
    parking: parking,
    updatedAt: updatedAt,
    isFromCache: isFromCache,
  );

  int? get totalSpaces {
    if (vehicleType == null) return null;

    return availability.capacityFor(vehicleType!);
  }

  int? get availableSpaces {
    final total = totalSpaces;
    if (total == null) return null;

    return availability.availableFor(vehicleType!);
  }

  double? get availabilityRatio {
    final total = totalSpaces;
    if (total == null) return null;
    if (total == 0) return 0;
    return availableSpaces! / total;
  }

  bool get canBeRecommended =>
      vehicleType != null && availability.canRecommend(vehicleType!);
}
