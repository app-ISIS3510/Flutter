import '../models/parking.dart';
import '../models/most_used_parking.dart';
import '../models/most_used_parking_ranking.dart';
import '../models/parking_catalog_snapshot.dart';
import '../models/parking_option.dart';
import '../models/smart_parking_result.dart';
import '../models/vehicle.dart';
import '../services/parking_service.dart';
import '../state/parking_list_state.dart';
import '../state/parking_detail_state.dart';
import '../state/nearby_parking_state.dart';
import '../models/parking_search_result.dart';

class ParkingController {
  final ParkingService service;

  ParkingController(this.service);

  Stream<ParkingListState> watchParkingLots() {
    return service.watchParkingLots();
  }

  Future<List<MostUsedParking>> loadMostUsedParkingLots() {
    return service.getMostUsedParkingLots();
  }

  Future<MostUsedParkingRanking> loadMostUsedParkingRanking() {
    return service.getMostUsedParkingRanking();
  }

  Future<List<Parking>> loadParkingLots() {
    return service.getParkingLots();
  }

  Future<ParkingCatalogSnapshot> loadParkingCatalog() {
    return service.getParkingCatalog();
  }

  Future<ParkingCatalogSnapshot?> loadCachedParkingCatalog() {
    return service.getCachedParkingCatalog();
  }

  Future<Parking?> loadParkingById(String id) {
    return service.getParkingById(id);
  }

  Future<ParkingDetailState> loadParkingDetails(String id) {
    return service.getParkingDetails(id);
  }

  ParkingDetailState? readMemoryParkingDetails(String id) {
    return service.readMemoryParkingDetails(id);
  }

  void clearParkingDetailsMemory() {
    service.clearParkingDetailsMemory();
  }

  Future<List<Parking>> searchParkingLots(String query) {
    return service.searchParkingLots(query);
  }

  Future<ParkingSearchResult> searchParkingLotsWithSource(String query) {
    return service.searchParkingLotsWithSource(query);
  }

  Future<List<Parking>> loadNearestParkingLots({int limit = 4}) {
    return service.getNearestParkingLots(limit: limit);
  }

  Future<List<ParkingOption>> loadParkingOptions({VehicleType? vehicleType}) {
    return service.getParkingOptions(vehicleType: vehicleType);
  }

  Future<NearbyParkingState> loadNearbyParking({VehicleType? vehicleType}) {
    return service.getNearbyParking(vehicleType: vehicleType);
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
