import '../models/parking.dart';
import '../models/most_used_parking.dart';
import '../models/parking_option.dart';
import '../models/smart_parking_result.dart';
import '../models/vehicle.dart';
import '../services/parking_service.dart';

class ParkingController {
  final ParkingService service;

  ParkingController(this.service);

  Future<List<MostUsedParking>> loadMostUsedParkingLots() {
    return service.getMostUsedParkingLots();
  }

  Future<List<Parking>> loadParkingLots() {
    return service.getParkingLots();
  }

  Future<Parking?> loadParkingById(String id) {
    return service.getParkingById(id);
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return service.searchParkingLots(query);
  }

  Future<List<Parking>> loadNearestParkingLots({int limit = 4}) {
    return service.getNearestParkingLots(limit: limit);
  }

  Future<List<ParkingOption>> loadParkingOptions({VehicleType? vehicleType}) {
    return service.getParkingOptions(vehicleType: vehicleType);
  }

  Future<SmartParkingResults> loadSmartParkingResults({
    required int radiusMeters,
    required SmartVehicleType vehicleType,
  }) {
    return service.getSmartParkingResults(
      radiusMeters: radiusMeters,
      vehicleType: vehicleType,
    );
  }
}
