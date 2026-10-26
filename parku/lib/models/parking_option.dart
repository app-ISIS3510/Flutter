import 'parking.dart';
import 'vehicle.dart';

class ParkingOption {
  final Parking parking;
  final double distanceMeters;
  final VehicleType? vehicleType;

  const ParkingOption({
    required this.parking,
    required this.distanceMeters,
    this.vehicleType,
  });

  int? get totalSpaces {
    if (vehicleType == null) return null;

    final total = vehicleType == VehicleType.car
        ? parking.carSpaces
        : parking.motorcycleSpaces;
    return total < 0 ? 0 : total;
  }

  int? get availableSpaces {
    final total = totalSpaces;
    if (total == null) return null;

    final available = vehicleType == VehicleType.car
        ? parking.availableCarSpaces
        : parking.availableMotorcycleSpaces;
    return available.clamp(0, total).toInt();
  }

  double? get availabilityRatio {
    final total = totalSpaces;
    if (total == null) return null;
    if (total == 0) return 0;
    return availableSpaces! / total;
  }

  bool get canBeRecommended => (availableSpaces ?? 0) > 0;
}
