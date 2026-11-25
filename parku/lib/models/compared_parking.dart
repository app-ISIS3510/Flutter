import 'parking.dart';

class ComparedParking {
  final Parking parking;
  final DateTime? updatedAt;
  final bool isFromCache;
  final bool isUnavailable;

  const ComparedParking(
    this.parking, {
    this.updatedAt,
    this.isFromCache = false,
    this.isUnavailable = false,
  });
}
