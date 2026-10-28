import 'parking.dart';

class SmartParkingResults {
  final List<SmartParkingResult> items;
  final String? locationNotice;

  const SmartParkingResults({required this.items, this.locationNotice});
}

class SmartParkingResult {
  final Parking parking;
  final double? distanceMeters;
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

  String? get formattedDistance {
    final distance = distanceMeters;
    if (distance == null) return null;
    if (distance < 1000) {
      return '${distance.round()} m';
    }

    return '${(distance / 1000).toStringAsFixed(2)} km';
  }
}
