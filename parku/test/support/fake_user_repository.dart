import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  UserProfile profile = const UserProfile(
    id: 'user-1',
    fullName: 'Alex Rivera',
    email: 'alex.rivera@uniandes.edu.co',
  );
  List<Vehicle> vehicles = [];
  bool signedOut = false;
  Object? failure;
  int addCalls = 0;
  @override
  Future<UserProfile> getProfile() async {
    if (failure != null) throw failure!;
    return profile;
  }

  @override
  Future<UserProfile> updateProfile(String name, String email) async {
    if (failure != null) throw failure!;
    return profile = UserProfile(id: profile.id, fullName: name, email: email);
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    if (failure != null) throw failure!;
    return List.of(vehicles);
  }

  @override
  Future<void> addVehicle(VehicleType type, String plate) async {
    addCalls++;
    if (failure != null) throw failure!;
    vehicles.add(
      Vehicle(
        id: 'vehicle-$addCalls',
        type: type,
        plate: plate,
        isSelected: vehicles.isEmpty,
      ),
    );
  }

  @override
  Future<void> selectVehicle(String id) async {
    vehicles = vehicles
        .map(
          (v) => Vehicle(
            id: v.id,
            type: v.type,
            plate: v.plate,
            isSelected: v.id == id,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteVehicle(String id) async {
    if (failure != null) throw failure!;
    vehicles.removeWhere((v) => v.id == id);
    if (vehicles.isNotEmpty && !vehicles.any((v) => v.isSelected)) {
      await selectVehicle(vehicles.first.id);
    }
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}
