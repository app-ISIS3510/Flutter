import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../services/profile_service.dart';
import '../services/driving_restriction_service.dart';
import '../services/connection_failure.dart';
import '../utils/user_error_message.dart';

class ProfileController extends ChangeNotifier {
  final ProfileService service;
  ProfileController(this.service);

  UserProfile? profile;
  List<Vehicle> _vehicles = [];
  bool loading = false;
  bool isAdmin = false;
  bool busy = false;
  bool changeQueued = false;
  String? error;
  int _version = 0;
  bool _disposed = false;

  bool get usingSavedData => service.usingSavedData;
  Map<String, dynamic>? get pendingChange => service.pendingChange;
  Map<String, dynamic>? get profileDraft => service.profileDraft;
  Map<String, dynamic>? get vehicleDraft => service.vehicleDraft;
  String? get notice {
    if (service.queuedChanges.isNotEmpty) {
      return 'Changes saved on this device. They will be sent when you reconnect.';
    }
    if (pendingChange != null) {
      return 'A previous change is not confirmed. Reconnect and refresh before retrying it.';
    }
    if (usingSavedData) {
      return 'Showing saved information. It may be out of date. Reconnect and refresh to update it.';
    }
    if (service.localSaveFailed) {
      return 'Your information loaded, but its offline copy could not be saved.';
    }
    return null;
  }

  String? get profileNotice => service.queuedChanges.isEmpty ? notice : null;

  ({String name, String email})? get queuedProfileEdit {
    for (final change in service.queuedChanges.reversed) {
      if (change['kind'] == 'profile') {
        return (
          name: change['name'] as String,
          email: change['email'] as String,
        );
      }
    }
    return null;
  }

  List<Vehicle> get vehicles {
    final deletedIds = {
      for (final change in service.queuedChanges)
        if (change['kind'] == 'delete_vehicle') change['id'],
    };
    if (deletedIds.isEmpty) return _vehicles;
    return _vehicles
        .where((vehicle) => !deletedIds.contains(vehicle.id))
        .toList();
  }

  List<({String plate, VehicleType type})> get pendingVehicleRegistrations {
    final registered = vehicles;
    return [
      for (final change in service.queuedChanges)
        if (change['kind'] == 'add_vehicle' &&
            !registered.any(
              (vehicle) =>
                  vehicle.plate == change['plate'] &&
                  vehicle.type.value == change['type'],
            ))
          (
            plate: change['plate'] as String,
            type: VehicleType.values.byName(change['type'] as String),
          ),
    ];
  }

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
    service.clear();
    profile = null;
    _vehicles = [];
    error = null;
    loading = false;
    busy = false;
    changeQueued = false;
    isAdmin = false;
    _notify();
  }

  Future<void> load() async {
    if (busy || loading || _disposed) return;
    final version = ++_version;
    loading = true;
    error = null;
    _notify();
    try {
      await service.restorePendingChange();
      if (version != _version) return;
      final savedProfile = await service.readSavedProfile();
      if (version != _version) return;
      final savedVehicles = await service.readSavedVehicles();
      if (version != _version) return;
      profile = savedProfile ?? profile;
      _vehicles = savedVehicles ?? _vehicles;
      _notify();
      final user = await service.getProfile();
      if (version != _version) return;
      profile = user;
      var adminStatus = false;
      try {
        adminStatus = await service.isAdmin();
      } catch (error, stackTrace) {
        // Load the profile even if the admin check fails.
        developer.log(
          'Could not verify dashboard access',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (version != _version) return;
      isAdmin = adminStatus;
      final currentVehicles = await service.getVehicles();
      if (version != _version) return;
      _vehicles = currentVehicles;
      await service.checkPendingChange();
      if (!service.usingSavedData && await service.syncPendingChanges()) {
        final updatedProfile = await service.getProfile();
        if (version != _version) return;
        profile = updatedProfile;
        final updatedVehicles = await service.getVehicles();
        if (version != _version) return;
        _vehicles = updatedVehicles;
      }
    } catch (e) {
      if (version == _version) error = messageFor(e);
    } finally {
      if (version == _version) {
        _vehicles = service.lastVehicles ?? _vehicles;
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
    changeQueued = false;
    error = null;
    final version = _version;
    _notify();
    try {
      await action();
      if (version != _version) return false;
      if (refreshVehicles) {
        await service.getVehicles();
        if (version != _version) return false;
        if (service.vehiclesFromCache) {
          throw const ConnectionFailure(
            'Your change was saved, but the vehicle list could not be refreshed. Reconnect and refresh before choosing a vehicle.',
          );
        }
      }
      return true;
    } on QueuedChange {
      if (version != _version) return false;
      changeQueued = true;
      return true;
    } catch (e) {
      if (version == _version) error = messageFor(e);
      return false;
    } finally {
      if (version == _version) {
        _vehicles = service.lastVehicles ?? _vehicles;
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
      error = userErrorMessage(e, action: ErrorAction.signOut);
      busy = false;
      _notify();
      return false;
    }
  }

  static String messageFor(Object error) {
    if (error is ConnectionFailure) {
      return error.message;
    }

    return userErrorMessage(error, action: ErrorAction.profile);
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    super.dispose();
  }
}
