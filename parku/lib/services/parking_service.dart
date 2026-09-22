import '../models/parking.dart';
import '../repositories/parking_repository.dart';

class ParkingService {
  final ParkingRepository repository;

  ParkingService(this.repository);

  Future<List<Parking>> getParkingLots() {
    return repository.getParkingLots();
  }

  Future<Parking?> getParkingById(String id) {
    return repository.getParkingById(id);
  }
}