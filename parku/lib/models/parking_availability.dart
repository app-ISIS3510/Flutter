import 'parking.dart';
import 'vehicle.dart';

/// The latest observed estimate, never a reservation or a guaranteed space.
class ParkingAvailability {
  final Parking parking;
  final DateTime? updatedAt;
  final bool isFromCache;

  const ParkingAvailability({
    required this.parking,
    this.updatedAt,
    this.isFromCache = false,
  });

  int capacityFor(VehicleType type) {
    final capacity = type == VehicleType.car
        ? parking.carSpaces
        : parking.motorcycleSpaces;
    return capacity < 0 ? 0 : capacity;
  }

  int availableFor(VehicleType type) {
    final available = type == VehicleType.car
        ? parking.availableCarSpaces
        : parking.availableMotorcycleSpaces;
    return available.clamp(0, capacityFor(type)).toInt();
  }

  double ratioFor(VehicleType type) {
    final capacity = capacityFor(type);
    return capacity == 0 ? 0 : availableFor(type) / capacity;
  }

  bool canRecommend(VehicleType type) => !isFromCache && availableFor(type) > 0;
}
