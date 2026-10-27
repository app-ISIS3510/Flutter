import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/models/parking_session.dart';
import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_user_repository.dart';
import 'memory_auth_storage.dart';

SupabaseClient offlineTestClient() => SupabaseClient(
  'https://test.invalid',
  'test-key',
  authOptions: AuthClientOptions(
    autoRefreshToken: false,
    pkceAsyncStorage: MemoryAuthStorage(),
  ),
  httpClient: MockClient(
    (request) async => http.Response('{}', 200, request: request),
  ),
);

Future<void> signInAs(SupabaseClient client, String id) async {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': id,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
          }),
        ),
      )
      .replaceAll('=', '');
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': id,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '$id@example.com',
        'created_at': '2026-10-01T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      },
    }),
  );
}

class UnstableUserRepository extends FakeUserRepository {
  bool online = true;
  bool loseReply = false;
  bool disconnectAfterWrite = false;
  int writes = 0;
  Completer<void>? profileGate;
  final profileReceived = Completer<void>();

  void _read() {
    if (!online) throw const SocketException('Offline');
  }

  void _afterWrite() {
    if (loseReply) {
      loseReply = false;
      if (disconnectAfterWrite) online = false;
      throw const SocketException('Response lost');
    }
  }

  @override
  Future<UserProfile> getProfile() async {
    _read();
    return super.getProfile();
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    _read();
    return super.getVehicles();
  }

  @override
  Future<bool> isAdmin() async {
    _read();
    return true;
  }

  @override
  Future<UserProfile> updateProfile(String name, String email) async {
    _read();
    writes++;
    if (!profileReceived.isCompleted) profileReceived.complete();
    if (profileGate != null) await profileGate!.future;
    final saved = await super.updateProfile(name, email);
    _afterWrite();
    return saved;
  }

  @override
  Future<void> addVehicle(VehicleType type, String plate) async {
    _read();
    writes++;
    await super.addVehicle(type, plate);
    _afterWrite();
  }

  @override
  Future<void> selectVehicle(String id) async {
    _read();
    writes++;
    await super.selectVehicle(id);
    _afterWrite();
  }

  @override
  Future<void> deleteVehicle(String id) async {
    _read();
    writes++;
    await super.deleteVehicle(id);
    _afterWrite();
  }
}

class UnstableSessionRepository extends SessionRepository {
  bool online = true;
  bool loseReply = false;
  bool disconnectAfterWrite = false;
  int starts = 0;
  int changes = 0;
  int ends = 0;
  final sessions = <ParkingSession>[];
  Completer<void>? startGate;
  final startReceived = Completer<void>();
  Completer<ParkingSession?>? activeReply;

  UnstableSessionRepository(super.client);

  void _read() {
    if (!online) throw const SocketException('Offline');
  }

  ParkingSession _afterWrite(ParkingSession session) {
    if (loseReply) {
      loseReply = false;
      if (disconnectAfterWrite) online = false;
      throw const SocketException('Response lost');
    }
    return session;
  }

  @override
  Future<ParkingSession?> getActiveSession() async {
    _read();
    if (activeReply != null) return activeReply!.future;
    for (final session in sessions) {
      if (session.userId == client.auth.currentUser?.id &&
          session.status == 'active') {
        return session;
      }
    }
    return null;
  }

  @override
  Future<ParkingSession?> getSessionById(String id) async {
    _read();
    for (final session in sessions) {
      if (session.id == id && session.userId == client.auth.currentUser?.id) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<List<ParkingSession>> getMatchingSessions({
    required String parkingId,
    required String vehicleId,
    required DateTime pickupTime,
  }) async {
    _read();
    return sessions
        .where(
          (session) =>
              session.userId == client.auth.currentUser?.id &&
              session.parkingId == parkingId &&
              session.vehicleId == vehicleId &&
              session.pickupTime.isAtSameMomentAs(pickupTime),
        )
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<ParkingSession> createSession({
    required String parkingId,
    required DateTime pickupTime,
    required String vehicleId,
  }) async {
    _read();
    starts++;
    if (!startReceived.isCompleted) startReceived.complete();
    final owner = client.auth.currentUser!.id;
    await startGate?.future;
    if (sessions.any(
      (session) => session.status == 'active' && session.userId == owner,
    )) {
      throw const PostgrestException(
        message: 'ACTIVE_SESSION_EXISTS',
        code: 'P0001',
      );
    }
    final session = ParkingSession(
      id: 'session-$starts',
      userId: owner,
      parkingId: parkingId,
      pickupTime: pickupTime,
      startedAt: DateTime.now(),
      status: 'active',
      vehicleId: vehicleId,
      vehiclePlate: 'ABC123',
    );
    sessions.add(session);
    return _afterWrite(session);
  }

  @override
  Future<ParkingSession> updatePickupTime({
    required String sessionId,
    required DateTime pickupTime,
    DateTime? previousPickupTime,
  }) async {
    _read();
    changes++;
    final index = sessions.indexWhere((session) => session.id == sessionId);
    final current = sessions[index];
    if (current.status != 'active' ||
        (previousPickupTime != null &&
            !current.pickupTime.isAtSameMomentAs(previousPickupTime))) {
      throw const PostgrestException(message: 'Session changed', code: 'P0001');
    }
    final updated = ParkingSession.fromMap({
      ...current.toMap(),
      'pickup_time': pickupTime.toIso8601String(),
    });
    sessions[index] = updated;
    return _afterWrite(updated);
  }

  @override
  Future<ParkingSession> endSession({required String sessionId}) async {
    _read();
    ends++;
    final index = sessions.indexWhere((session) => session.id == sessionId);
    final updated = ParkingSession.fromMap({
      ...sessions[index].toMap(),
      'status': 'completed',
      'ended_at': DateTime.now().toIso8601String(),
    });
    sessions[index] = updated;
    return _afterWrite(updated);
  }
}
