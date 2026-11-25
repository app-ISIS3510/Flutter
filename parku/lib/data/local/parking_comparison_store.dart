import '../../models/compared_parking.dart';

abstract interface class ParkingComparisonStore {
  Future<List<ComparedParking>> read(String owner);
  Future<void> write(String owner, List<ComparedParking> selection);
}
