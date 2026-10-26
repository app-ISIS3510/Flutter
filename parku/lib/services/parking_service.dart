import '../models/parking.dart';
import '../models/parking_option.dart';
import '../models/vehicle.dart';
import '../repositories/parking_repository.dart';
import 'distance_manager.dart';

class ParkingService {
  final ParkingRepository repository;
  final DistanceManager distanceManager;

  ParkingService(this.repository, this.distanceManager);

  Future<List<Parking>> getParkingLots() {
    return repository.getParkingLots();
  }

  Future<Parking?> getParkingById(String id) {
    return repository.getParkingById(id);
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return repository.searchParkingLots(query);
  }

  Future<List<Parking>> getNearestParkingLots({int limit = 4}) async {
    final options = await getParkingOptions();
    return options.take(limit).map((option) => option.parking).toList();
  }

  Future<List<ParkingOption>> getParkingOptions({
    VehicleType? vehicleType,
  }) async {
    final parkingLots = await repository.getParkingLots();
    final parkingWithLocation = parkingLots.where((parking) {
      final latitude = parking.latitude;
      final longitude = parking.longitude;
      return latitude != null &&
          longitude != null &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180;
    }).toList();

    if (parkingWithLocation.isEmpty) return [];

    final position = await distanceManager.getCurrentPosition();
    final options = parkingWithLocation.map((parking) {
      return ParkingOption(
        parking: parking,
        distanceMeters: distanceManager.calculateDistance(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          parkingLatitude: parking.latitude!,
          parkingLongitude: parking.longitude!,
        ),
        vehicleType: vehicleType,
      );
    }).toList();

    options.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return options;
  }
}
