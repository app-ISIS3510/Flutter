import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../repositories/user_repository.dart';

class ProfileService {
  final UserRepository repository;
  ProfileService(this.repository);

  static String? validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) return 'Enter your full name.';
    if (name.length > 100) return 'Use 100 characters or fewer.';
    return null;
  }

  static String? validateEmail(String value) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ||
        value.trim().length > 254) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String normalizePlate(String value) => value.trim().toUpperCase();

  static String? validatePlate(VehicleType type, String value) {
    final plate = normalizePlate(value);
    final pattern = type == VehicleType.car
        ? r'^[A-Z]{3}[0-9]{3}$'
        : r'^[A-Z]{3}[0-9]{2}[A-Z]$';
    return RegExp(pattern).hasMatch(plate)
        ? null
        : 'Enter a complete license plate to continue.';
  }

  Future<UserProfile> getProfile() => repository.getProfile();
  Future<List<Vehicle>> getVehicles() => repository.getVehicles();
  Future<UserProfile> updateProfile(String name, String email) {
    final error = validateName(name) ?? validateEmail(email);
    if (error != null) throw FormatException(error);
    return repository.updateProfile(name.trim(), email.trim());
  }

  Future<void> addVehicle(VehicleType type, String plate) {
    final error = validatePlate(type, plate);
    if (error != null) throw FormatException(error);
    return repository.addVehicle(type, normalizePlate(plate));
  }

  Future<void> selectVehicle(String id) => repository.selectVehicle(id);
  Future<void> deleteVehicle(String id) => repository.deleteVehicle(id);
  Future<void> signOut() => repository.signOut();
}
