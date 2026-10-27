import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../repositories/personal_data_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/user_local_store.dart';
import 'connection_failure.dart';

class ProfileService {
  final UserRepository repository;
  final PersonalDataRepository? local;
  final UserLocalStore? store;
  final Duration requestTimeout;
  bool profileFromCache = false;
  bool vehiclesFromCache = false;
  bool localSaveFailed = false;
  Map<String, dynamic>? pendingChange;
  Map<String, dynamic>? profileDraft;
  Map<String, dynamic>? vehicleDraft;
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
  });

  bool get usingSavedData => profileFromCache || vehiclesFromCache;

  String? get _owner => store?.userId;

  void _checkOwner(String? owner) {
    if (owner != null) store!.checkUser(owner);
  }

  void clear() {
    _lastProfile = null;
    _lastVehicles = null;
    _profileOwner = null;
    _vehiclesOwner = null;
    pendingChange = null;
    profileDraft = null;
    vehicleDraft = null;
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

  Future<void> _saveProfile(UserProfile profile, String? owner) async {
    _checkOwner(owner);
    if (owner != null && profile.id != owner) {
      throw const AuthException('The signed-in account has changed.');
    }
    _lastProfile = profile;
    _profileOwner = owner;
    try {
      await local?.saveProfile(profile);
    } catch (_) {
      localSaveFailed = true;
    }
    _checkOwner(owner);
  }

  Future<void> _saveVehicles(List<Vehicle> vehicles, String? owner) async {
    _checkOwner(owner);
    _lastVehicles = vehicles;
    _vehiclesOwner = owner;
    try {
      if (owner != null) await local?.saveVehicles(owner, vehicles);
    } catch (_) {
      localSaveFailed = true;
    }
    _checkOwner(owner);
  }

  Future<UserProfile> getProfile() async {
    final owner = _owner;
    profileFromCache = false;
    try {
      final profile = await repository.getProfile().timeout(requestTimeout);
      await _saveProfile(profile, owner);
      return profile;
    } catch (error) {
      if (!isConnectionError(error) || store == null) rethrow;
      UserProfile? saved = _profileOwner == owner ? _lastProfile : null;
      try {
        if (saved == null && owner != null) {
          saved = await local?.getProfile(owner);
        }
      } catch (_) {
        localSaveFailed = true;
      }
      _checkOwner(owner);
      if (saved == null && repository is SupabaseUserRepository) {
        final cached = (repository as SupabaseUserRepository).cachedProfile;
        if (cached?.id == owner) saved = cached;
      }
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
  }

  Future<bool> isAdmin() async {
    if (profileFromCache) return false;
    try {
      return await repository.isAdmin().timeout(requestTimeout);
    } catch (error) {
      if (!isConnectionError(error)) rethrow;
      return false;
    }
  }

  Future<List<Vehicle>> getVehicles() async {
    final owner = _owner;
    vehiclesFromCache = false;
    try {
      final vehicles = await repository.getVehicles().timeout(requestTimeout);
      await _saveVehicles(vehicles, owner);
      return vehicles;
    } catch (error) {
      if (!isConnectionError(error) || store == null) rethrow;
      List<Vehicle>? saved = _vehiclesOwner == owner ? _lastVehicles : null;
      try {
        if (saved == null && owner != null) {
          saved = await local?.getVehicles(owner);
        }
      } catch (_) {
        localSaveFailed = true;
      }
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
      pendingChange = pending;
      profileDraft = profile;
      vehicleDraft = vehicle;
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
      if (request['kind'] == 'profile') await store?.remove('draft_profile');
      if (request['kind'] == 'add_vehicle') {
        await store?.remove('draft_add_vehicle');
      }
    } catch (error) {
      if (error is AuthException) rethrow;
      localSaveFailed = true;
    }
    _checkOwner(owner);
    pendingChange = null;
    if (request['kind'] == 'profile') profileDraft = null;
    if (request['kind'] == 'add_vehicle') vehicleDraft = null;
  }

  Future<void> checkPendingChange() async {
    final pending = pendingChange;
    if (pending == null) return;
    final saved = pending['kind'] == 'profile'
        ? profileFromCache
        : vehiclesFromCache;
    if (!saved && _matches(pending)) await _clearPending(_owner, pending);
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
    Future<void> Function() send,
  ) async {
    if (store == null) {
      await send().timeout(requestTimeout);
      return;
    }
    final owner = _owner;
    await restorePendingChange(strict: true);
    if (pendingChange != null &&
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
    try {
      if (await _verify(request, owner)) {
        await _clearPending(owner, request);
        return;
      }
    } catch (error) {
      if (!isConnectionError(error)) rethrow;
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

  Future<UserProfile> updateProfile(String name, String email) async {
    final error = validateName(name) ?? validateEmail(email);
    if (error != null) throw FormatException(error);
    final owner = _owner;
    UserProfile? result;
    await _change(
      {'kind': 'profile', 'name': name.trim(), 'email': email.trim()},
      () async {
        result = await repository.updateProfile(name.trim(), email.trim());
      },
    );
    if (result != null) await _saveProfile(result!, owner);
    return result ?? _lastProfile!;
  }

  Future<void> addVehicle(VehicleType type, String plate) async {
    final error = validatePlate(type, plate);
    if (error != null) throw FormatException(error);
    await _change({
      'kind': 'add_vehicle',
      'type': type.value,
      'plate': normalizePlate(plate),
    }, () => repository.addVehicle(type, normalizePlate(plate)));
  }

  Future<void> selectVehicle(String id) => _change({
    'kind': 'select_vehicle',
    'id': id,
  }, () => repository.selectVehicle(id));
  Future<void> deleteVehicle(String id) => _change({
    'kind': 'delete_vehicle',
    'id': id,
  }, () => repository.deleteVehicle(id));
  Future<void> signOut() => repository.signOut();
}
