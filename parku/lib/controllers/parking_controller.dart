import '../models/parking.dart';
import '../services/parking_service.dart';

class ParkingController {
  final ParkingService service;

  ParkingController(this.service);

  Future<List<Parking>> loadParkingLots() {
    return service.getParkingLots();
  }

  Future<Parking?> loadParkingById(String id) {
    return service.getParkingById(id);
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return service.searchParkingLots(query);
  }

  Future<List<Parking>> loadNearestParkingLots({
    int limit = 4,
  }) {
    return service.getNearestParkingLots(
      limit: limit,
    );
  }
  
}