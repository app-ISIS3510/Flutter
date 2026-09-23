import '../models/parking.dart';
import '../repositories/parking_repository.dart';
import 'distance_manager.dart';

class ParkingService {
  final ParkingRepository repository;
  final DistanceManager distanceManager;

  ParkingService(
    this.repository,
    this.distanceManager,
  );

  Future<List<Parking>> getParkingLots() {
    return repository.getParkingLots();
  }

  Future<Parking?> getParkingById(String id) {
    return repository.getParkingById(id);
  }

  Future<List<Parking>> searchParkingLots(
    String query,
  ) {
    return repository.searchParkingLots(query);
  }

  Future<List<Parking>> getNearestParkingLots({
    int limit = 4,
  }) async {
    final parkingLots =
        await repository.getParkingLots();

    final position =
        await distanceManager.getCurrentPosition();

    final parkingWithLocation = parkingLots
        .where(
          (parking) =>
              parking.latitude != null &&
              parking.longitude != null,
        )
        .toList();

    parkingWithLocation.sort(
      (a, b) {
        final distanceA =
            distanceManager.calculateDistance(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          parkingLatitude: a.latitude!,
          parkingLongitude: a.longitude!,
        );

        final distanceB =
            distanceManager.calculateDistance(
          userLatitude: position.latitude,
          userLongitude: position.longitude,
          parkingLatitude: b.latitude!,
          parkingLongitude: b.longitude!,
        );

        return distanceA.compareTo(distanceB);
      },
    );

    return parkingWithLocation
        .take(limit)
        .toList();
  }
}