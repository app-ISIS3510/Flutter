import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/profile_service.dart';
import '../services/driving_restriction_service.dart';

class ProfileController extends ChangeNotifier {
  final ProfileService service;
  ProfileController(this.service);

  UserProfile? profile;
  List<Vehicle> vehicles = [];
  bool loading = false;
  bool busy = false;
  String? error;
  int _version = 0;
  bool _disposed = false;

  Vehicle? get selectedVehicle {
    for (final vehicle in vehicles) {
      if (vehicle.isSelected) return vehicle;
    }
    return null;
  }

  DrivingRestriction? drivingRestriction({DateTime? now}) {
    final vehicle = selectedVehicle;
    return vehicle == null
        ? null
        : DrivingRestrictionService().check(vehicle, now: now);
  }

  void clearError() {
    if (error == null) return;
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clear() {
    _version++;
    profile = null;
    vehicles = [];
    error = null;
    loading = false;
    busy = false;
    _notify();
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    final version = ++_version;
    loading = true;
    error = null;
    _notify();
    try {
      final user = await service.getProfile();
      if (version != _version) return;
      profile = user;
      final savedVehicles = await service.getVehicles();
      if (version != _version) return;
      vehicles = savedVehicles;
    } catch (e) {
      if (version == _version) error = messageFor(e);
    } finally {
      if (version == _version) {
        loading = false;
        _notify();
      }
    }
  }

  Future<bool> _change(
    Future<void> Function() action, {
    bool refreshVehicles = true,
  }) async {
    if (busy || loading || _disposed) return false;
    busy = true;
    error = null;
    final version = _version;
    _notify();
    try {
      await action();
      if (version != _version) return false;
      final savedVehicles = refreshVehicles
          ? await service.getVehicles()
          : vehicles;
      if (version != _version) return false;
      vehicles = savedVehicles;
      return true;
    } catch (e) {
      if (version == _version) error = messageFor(e);
      return false;
    } finally {
      if (version == _version) {
        busy = false;
        _notify();
      }
    }
  }

  Future<bool> saveProfile(String name, String email) => _change(() async {
    final version = _version;
    final saved = await service.updateProfile(name, email);
    if (version == _version) profile = saved;
  }, refreshVehicles: false);
  Future<bool> addVehicle(VehicleType type, String plate) =>
      _change(() => service.addVehicle(type, plate));
  Future<bool> selectVehicle(String id) =>
      _change(() => service.selectVehicle(id));
  Future<bool> deleteVehicle(String id) =>
      _change(() => service.deleteVehicle(id));

  Future<bool> signOut() async {
    if (busy || loading || _disposed) return false;
    busy = true;
    error = null;
    final version = _version;
    _notify();
    try {
      await service.signOut();
      if (version != _version) return false;
      clear();
      return true;
    } catch (e) {
      if (version != _version) return false;
      error = messageFor(e);
      busy = false;
      _notify();
      return false;
    }
  }

  static String messageFor(Object error) {
    if (error is FormatException) return error.message;
    if (error is AuthException) return error.message;
    if (error is PostgrestException) {
      if (error.code == '23505') {
        return 'You have already saved this license plate.';
      }
      if (error.message.contains('VEHICLE_IN_USE')) {
        return 'This vehicle has an active parking session. End it before deleting the vehicle.';
      }
      if (error.message.contains('VEHICLE_NOT_FOUND')) {
        return 'This vehicle is no longer available. Refresh your vehicles.';
      }
      if (error.message.contains('SIGN_IN_REQUIRED')) {
        return 'Sign in to continue.';
      }
    }
    return 'Could not save or load your information. Check your connection and try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
