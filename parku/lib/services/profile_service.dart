import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../repositories/personal_data_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_local_store.dart';
import '../utils/error_messages.dart';
import 'connection_failure.dart';
import 'connectivity_service.dart';

class ProfileService {
  final UserRepository repository;
  final PersonalDataRepository? local;
  final UserLocalStore? store;
  final Duration requestTimeout;
  final Future<bool?> Function() checkConnection;

  bool profileFromCache = false;
  bool vehiclesFromCache = false;
  bool localSaveFailed = false;

  Map<String, dynamic>? pendingChange;
  Map<String, dynamic>? profileDraft;
  Map<String, dynamic>? vehicleDraft;
  List<Map<String, dynamic>> queuedChanges = [];
  bool _syncing = false;

  UserProfile? _lastProfile;
  List<Vehicle>? _lastVehicles;
  String? _profileOwner;
  String? _vehiclesOwner;

  final _inFlight = <String, Future<void>>{};

  ProfileService(
    this.repository, {
    this.local,
    this.store,
    this.requestTimeout = const Duration(seconds: 8),
    Future<bool?> Function()? checkConnection,
  }) : checkConnection =
           checkConnection ?? ConnectivityService().connectionStatus;

  bool get usingSavedData => profileFromCache || vehiclesFromCache;

  String? get _owner => store?.userId;

  void _checkOwner(String? owner) {
    if (owner != null) {
      store!.checkUser(owner);
    }
  }

  void clear() {
    _lastProfile = null;
    _lastVehicles = null;
    _profileOwner = null;
    _vehiclesOwner = null;
    pendingChange = null;
    profileDraft = null;
    vehicleDraft = null;
    queuedChanges = [];
    profileFromCache = false;
    vehiclesFromCache = false;
    localSaveFailed = false;
    _inFlight.clear();
  }

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

  static String normalizePlate(String value) {
    return value.trim().toUpperCase();
  }

  static String? validatePlate(VehicleType type, String value) {
    final plate = normalizePlate(value);

    final pattern = type == VehicleType.car
        ? r'^[A-Z]{3}[0-9]{3}$'
        : r'^[A-Z]{3}[0-9]{2}[A-Z]$';

    return RegExp(pattern).hasMatch(plate)
        ? null
        : 'Enter a complete license plate to continue.';
  }

  Future<void> _saveProfile(UserProfile profile, String? owner) async {
    _checkOwner(owner);

    if (owner != null && profile.id != owner) {
      throw const AuthException('The signed-in account has changed.');
    }

    _lastProfile = profile;
    _profileOwner = owner;
    profileFromCache = false;

    try {
      if (local != null && !kIsWeb) {
        await local!.saveProfile(profile);
      } else {
        await store?.write('saved_profile', {
          'id': profile.id,
          'name': profile.fullName,
          'email': profile.email,
          'pending_email': profile.pendingEmail,
        });
      }
    } catch (_) {
      localSaveFailed = true;
    }

    _checkOwner(owner);
  }

  Future<void> _saveVehicles(List<Vehicle> vehicles, String? owner) async {
    _checkOwner(owner);

    _lastVehicles = vehicles;
    _vehiclesOwner = owner;
    vehiclesFromCache = false;

    try {
      if (owner != null) {
        if (local != null && !kIsWeb) {
          await local!.saveVehicles(owner, vehicles);
        } else {
          await store?.write('saved_vehicles', {
            'vehicles': vehicles
                .map(
                  (vehicle) => {
                    'id': vehicle.id,
                    'vehicle_type': vehicle.type.value,
                    'plate': vehicle.plate,
                    'is_selected': vehicle.isSelected,
                  },
                )
                .toList(),
          });
        }
      }
    } catch (_) {
      localSaveFailed = true;
    }

    _checkOwner(owner);
  }

  Future<UserProfile> getProfile() async {
    final owner = _owner;

    if (await checkConnection() == false) return _savedProfile(owner);

    try {
      final profile = await repository.getProfile().timeout(requestTimeout);
      await _saveProfile(profile, owner);
      return profile;
    } catch (error) {
      if (!isConnectionError(error) || store == null) rethrow;

      return _savedProfile(owner);
    }
  }

  Future<UserProfile?> readSavedProfile() async {
    final owner = _owner;
    _checkOwner(owner);
    if (_profileOwner == owner && _lastProfile != null) {
      profileFromCache = true;
      return _lastProfile;
    }
    if (owner == null) return null;
    UserProfile? saved;
    try {
      if (local != null && !kIsWeb) {
        saved = await local!.getProfile(owner);
      } else {
        final data = await store?.read('saved_profile');
        if (data != null && data['id'] == owner) {
          saved = UserProfile(
            id: owner,
            fullName: data['name'] as String,
            email: data['email'] as String,
            pendingEmail: data['pending_email'] as String?,
          );
        }
      }
    } catch (_) {
      localSaveFailed = true;
    }
    _checkOwner(owner);
    if (saved != null) profileFromCache = true;
    return saved;
  }

  Future<UserProfile> _savedProfile(String? owner) async {
    final saved = await readSavedProfile();
    _checkOwner(owner);
    if (saved == null) {
      throw const ConnectionFailure(
        'No saved profile is available. Connect to the internet and try again.',
      );
    }
    profileFromCache = true;
    _lastProfile = saved;
    _profileOwner = owner;
    return saved;
  }

  Future<bool> isAdmin() async {
    if (profileFromCache) return false;

    try {
      return await repository.isAdmin().timeout(const Duration(seconds: 4));
    } catch (error) {
      if (!isConnectionError(error)) rethrow;
      return false;
    }
  }

  Future<List<Vehicle>> getVehicles() async {
    final owner = _owner;

    if (await checkConnection() == false) return _savedVehicles(owner);

    try {
      final vehicles = await repository.getVehicles().timeout(requestTimeout);
      await _saveVehicles(vehicles, owner);
      return vehicles;
    } catch (error) {
      if (!isConnectionError(error) || store == null) rethrow;

      return _savedVehicles(owner);
    }
  }

  Future<List<Vehicle>?> readSavedVehicles() async {
    final owner = _owner;
    _checkOwner(owner);
    if (_vehiclesOwner == owner && _lastVehicles != null) {
      vehiclesFromCache = true;
      return _lastVehicles;
    }
    if (owner == null) return null;
    List<Vehicle>? saved;
    try {
      if (local != null && !kIsWeb) {
        saved = await local!.getVehicles(owner);
      } else {
        final data = await store?.read('saved_vehicles');
        if (data != null) {
          saved = (data['vehicles'] as List)
              .map((row) => Vehicle.fromMap(Map<String, dynamic>.from(row)))
              .toList();
        }
      }
    } catch (_) {
      localSaveFailed = true;
    }
    _checkOwner(owner);
    if (saved != null) vehiclesFromCache = true;
    return saved;
  }

  Future<List<Vehicle>> _savedVehicles(String? owner) async {
    final saved = await readSavedVehicles();
    _checkOwner(owner);
    if (saved == null) {
      throw const ConnectionFailure(
        'No saved vehicles are available. Connect to load your vehicles.',
      );
    }
    vehiclesFromCache = true;
    _lastVehicles = saved;
    _vehiclesOwner = owner;
    return saved;
  }

  Future<void> restorePendingChange({bool strict = false}) async {
    final owner = _owner;

    try {
      final pending = await store?.read('profile_request');
      _checkOwner(owner);

      final profile = await store?.read('draft_profile');
      _checkOwner(owner);

      final vehicle = await store?.read('draft_add_vehicle');
      _checkOwner(owner);

      final queued = await store?.read('profile_queue');
      _checkOwner(owner);

      pendingChange = pending;
      profileDraft = profile;
      vehicleDraft = vehicle;
      queuedChanges = (queued?['changes'] as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      if (error is AuthException || strict) rethrow;
      localSaveFailed = true;
    }
  }

  bool _matches(Map<String, dynamic> request) {
    if (request['kind'] == 'profile') {
      return _lastProfile?.fullName == request['name'] &&
          (_lastProfile?.email == request['email'] ||
              _lastProfile?.pendingEmail == request['email']);
    }

    final vehicles = _lastVehicles;
    if (vehicles == null) return false;

    return switch (request['kind']) {
      'add_vehicle' => vehicles.any(
        (vehicle) =>
            vehicle.plate == request['plate'] &&
            vehicle.type.value == request['type'],
      ),
      'select_vehicle' => vehicles.any(
        (vehicle) => vehicle.id == request['id'] && vehicle.isSelected,
      ),
      'delete_vehicle' => vehicles.every(
        (vehicle) => vehicle.id != request['id'],
      ),
      _ => false,
    };
  }

  Future<void> _clearPending(
    String? owner,
    Map<String, dynamic> request,
  ) async {
    _checkOwner(owner);

    try {
      await store?.remove('profile_request');

      if (request['kind'] == 'profile') {
        await store?.remove('draft_profile');
      }

      if (request['kind'] == 'add_vehicle') {
        await store?.remove('draft_add_vehicle');
      }
    } catch (error) {
      if (error is AuthException) rethrow;
      localSaveFailed = true;
    }

    _checkOwner(owner);
    pendingChange = null;

    if (request['kind'] == 'profile') {
      profileDraft = null;
    }

    if (request['kind'] == 'add_vehicle') {
      vehicleDraft = null;
    }
  }

  Future<void> checkPendingChange() async {
    final pending = pendingChange;
    if (pending == null) return;

    final saved = pending['kind'] == 'profile'
        ? profileFromCache
        : vehiclesFromCache;

    if (!saved && _matches(pending)) {
      await _clearPending(_owner, pending);
    }
  }

  Future<bool> _verify(Map<String, dynamic> request, String? owner) async {
    if (request['kind'] == 'profile') {
      final profile = await repository.getProfile().timeout(requestTimeout);
      await _saveProfile(profile, owner);
    } else {
      final vehicles = await repository.getVehicles().timeout(requestTimeout);
      await _saveVehicles(vehicles, owner);
    }

    return _matches(request);
  }

  Future<void> _change(
    Map<String, dynamic> request,
    Future<void> Function() send, {
    bool replaying = false,
  }) async {
    final offline = await checkConnection() == false;
    if (offline && request['kind'] == 'add_vehicle') {
      throw const ConnectionFailure(
        'Connect to the internet to save a vehicle. Your plate has not been registered.',
      );
    }
    if (store == null) {
      if (offline) {
        throw const ConnectionFailure('Connect to save your changes.');
      }
      await send().timeout(requestTimeout);
      return;
    }

    final owner = _owner;

    await restorePendingChange(strict: true);

    if (request['kind'] == 'add_vehicle' &&
        pendingChange != null &&
        jsonEncode(pendingChange) != jsonEncode(request)) {
      throw const ConnectionFailure(
        'A previous change is still unconfirmed. Refresh and retry that change first.',
      );
    }

    if (request['kind'] == 'profile') {
      profileDraft = request;
      await store!.write('draft_profile', request);
    }

    if (request['kind'] == 'add_vehicle') {
      vehicleDraft = request;
      await store!.write('draft_add_vehicle', request);
    }

    _checkOwner(owner);

    if (!replaying &&
        queuedChanges.isNotEmpty &&
        request['kind'] != 'add_vehicle') {
      await _queueChange(request, owner);
      if (!offline) {
        try {
          if (await syncPendingChanges()) return;
        } catch (error) {
          if (!isConnectionError(error)) rethrow;
        }
      }
      throw const QueuedChange(
        'Your change is saved on this device. It will be sent when you reconnect.',
      );
    }

    if (offline) {
      if (!replaying) await _queueChange(request, owner);
      throw const QueuedChange(
        'Your change is saved on this device. It will be sent when you reconnect.',
      );
    }

    if (pendingChange != null &&
        jsonEncode(pendingChange) != jsonEncode(request)) {
      throw const ConnectionFailure(
        'A previous change is still unconfirmed. Refresh and retry that change first.',
      );
    }

    try {
      if (await _verify(request, owner)) {
        await _clearPending(owner, request);
        return;
      }
    } catch (error) {
      if (!isConnectionError(error)) rethrow;

      if (!replaying && request['kind'] != 'add_vehicle') {
        await _queueChange(request, owner);
        throw const QueuedChange(
          'Your change is saved on this device. It will be sent when you reconnect.',
        );
      }

      throw ConnectionFailure(
        pendingChange == null
            ? 'A connection is needed to save changes. Your input has been kept.'
            : 'The previous change is still unconfirmed. Reconnect and try again.',
      );
    }

    final requestKey = jsonEncode([owner, request]);

    if (_inFlight.containsKey(requestKey)) {
      throw const ConnectionFailure(
        'The earlier change is still being processed. Refresh before retrying.',
      );
    }

    await store!.write('profile_request', request);
    pendingChange = request;
    _checkOwner(owner);

    try {
      final response = send();
      _inFlight[requestKey] = response;

      void finished() {
        if (identical(_inFlight[requestKey], response)) {
          _inFlight.remove(requestKey);
        }
      }

      unawaited(
        response.then<void>(
          (_) => finished(),
          onError: (Object _, StackTrace _) => finished(),
        ),
      );

      await response.timeout(requestTimeout);
      _checkOwner(owner);
    } catch (error) {
      if (!isConnectionError(error)) {
        await _clearPending(owner, request);
        rethrow;
      }

      try {
        if (await _verify(request, owner)) {
          await _clearPending(owner, request);
          return;
        }
      } catch (checkError) {
        if (!isConnectionError(checkError)) rethrow;
      }

      if (!replaying && request['kind'] != 'add_vehicle') {
        await _queueChange(request, owner);
        throw const QueuedChange(
          'Your change is pending confirmation. It will be checked when you reconnect.',
        );
      }

      throw const ConnectionFailure(
        'We could not confirm the change. Your input has been kept. Reconnect and refresh before retrying.',
      );
    }

    try {
      await _clearPending(owner, request);
    } catch (_) {
      localSaveFailed = true;
    }
  }

  Future<void> _queueChange(Map<String, dynamic> request, String? owner) async {
    _checkOwner(owner);
    final next = [...queuedChanges];
    if (request['kind'] == 'profile' || request['kind'] == 'select_vehicle') {
      next.removeWhere(
        (saved) =>
            saved['kind'] == request['kind'] &&
            jsonEncode(saved) != jsonEncode(pendingChange),
      );
    }
    if (!next.any((saved) => jsonEncode(saved) == jsonEncode(request))) {
      next.add(Map.of(request));
    }
    await store!.write('profile_queue', {'changes': next});
    _checkOwner(owner);
    queuedChanges = next;
  }

  Future<bool> syncPendingChanges() async {
    if (store == null || _syncing) return false;
    _syncing = true;
    final owner = _owner;
    var changed = false;
    try {
      if (await checkConnection() == false) return false;
      _checkOwner(owner);
      await restorePendingChange(strict: true);
      final pending = pendingChange;
      if (pending != null && pending['kind'] != 'add_vehicle') {
        await _change(
          pending,
          () => _sendStoredChange(pending),
          replaying: true,
        );
        _checkOwner(owner);
        changed = true;
      }
      while (queuedChanges.isNotEmpty) {
        final request = queuedChanges.first;
        await _change(
          request,
          () => _sendStoredChange(request),
          replaying: true,
        );
        _checkOwner(owner);
        final next = queuedChanges.skip(1).toList();
        await store!.write('profile_queue', {'changes': next});
        _checkOwner(owner);
        queuedChanges = next;
        changed = true;
      }
      return changed;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _sendStoredChange(Map<String, dynamic> request) async {
    switch (request['kind']) {
      case 'profile':
        final owner = _owner;
        final saved = await repository.updateProfile(
          request['name'] as String,
          request['email'] as String,
        );
        await _saveProfile(saved, owner);
      case 'select_vehicle':
        await repository.selectVehicle(request['id'] as String);
      case 'delete_vehicle':
        await repository.deleteVehicle(request['id'] as String);
      default:
        throw const ConnectionFailure(
          'This saved change needs to be reviewed.',
        );
    }
  }

  Future<UserProfile> updateProfile(String name, String email) async {
    final error = validateName(name) ?? validateEmail(email);

    if (error != null) {
      throw UserInputException(error);
    }

    final owner = _owner;
    UserProfile? result;

    await _change(
      {'kind': 'profile', 'name': name.trim(), 'email': email.trim()},
      () async {
        result = await repository.updateProfile(name.trim(), email.trim());
      },
    );

    if (result != null) {
      await _saveProfile(result!, owner);
    }

    return result ?? _lastProfile!;
  }

  Future<void> addVehicle(VehicleType type, String plate) async {
    final error = validatePlate(type, plate);

    if (error != null) {
      throw UserInputException(error);
    }

    await _change({
      'kind': 'add_vehicle',
      'type': type.value,
      'plate': normalizePlate(plate),
    }, () => repository.addVehicle(type, normalizePlate(plate)));
  }

  Future<void> selectVehicle(String id) {
    return _change({
      'kind': 'select_vehicle',
      'id': id,
    }, () => repository.selectVehicle(id));
  }

  Future<void> deleteVehicle(String id) {
    return _change({
      'kind': 'delete_vehicle',
      'id': id,
    }, () => repository.deleteVehicle(id));
  }

  Future<void> signOut() => repository.signOut();
}
