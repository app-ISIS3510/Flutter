
import 'parking.dart';

class SmartParkingResult {
  final Parking parking;
  final double distanceMeters;
  final double availabilityPercentage;
  final int availableSpaces;
  final int totalSpaces;
  final bool isRecommended;

  const SmartParkingResult({
    required this.parking,
    required this.distanceMeters,
    required this.availabilityPercentage,
    required this.availableSpaces,
    required this.totalSpaces,
    required this.isRecommended,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }
}
