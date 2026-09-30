import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/repositories/user_repository.dart';
import 'package:parku/repositories/session_repository.dart';

class MemoryAuthStorage extends GotrueAsyncStorage {
  final values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late SupabaseUserRepository repository;
  late List<http.Request> requests;
  late Map<String, dynamic> user;

  setUp(() async {
    requests = [];
    user = {
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'alex@example.com',
      'created_at': '2026-09-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'full_name': 'Alex'},
    };
    client = SupabaseClient(
      'https://test.invalid',
      'test-public-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object result = {};
        if (path == '/auth/v1/user') {
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            user['user_metadata'] = body['data'];
            if (body['email'] != null) user['new_email'] = body['email'];
          }
          result = user;
        } else if (path == '/rest/v1/vehicles') {
          result = [
            {
              'id': 'vehicle-1',
              'vehicle_type': 'car',
              'plate': 'ABC123',
              'is_selected': true,
            },
          ];
        } else if (path == '/rest/v1/rpc/start_parking_with_vehicle') {
          result = {
            'id': 'session-1',
            'user_id': 'user-1',
            'parking_id': 'parking-1',
            'pickup_time': '2026-09-30T21:00:00Z',
            'started_at': '2026-09-30T20:00:00Z',
            'status': 'active',
            'vehicle_id': 'vehicle-1',
            'vehicle_type': 'car',
            'vehicle_plate': 'ABC123',
          };
        } else if (path == '/rest/v1/parking_sessions') {
          result = [];
        } else if (!path.startsWith('/rest/v1/rpc/') &&
            path != '/auth/v1/logout') {
          throw StateError('Unexpected request: ${request.method} $path');
        }
        return http.Response(
          jsonEncode(result),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'user-1',
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    // Sesión sintética para el cliente HTTP simulado; no sirve en Supabase real.
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': user,
      }),
    );
    repository = SupabaseUserRepository(client);
  });
  tearDown(() async => client.dispose());

  test(
    'loads the authenticated profile and filters vehicles by owner',
    () async {
      expect((await repository.getProfile()).fullName, 'Alex');
      expect((await repository.getVehicles()).single.plate, 'ABC123');
      final request = requests.last;
      expect(request.url.queryParameters['user_id'], 'eq.user-1');
      expect(request.headers['Authorization'], startsWith('Bearer '));
    },
  );
  test(
    'changing the name does not request another email confirmation',
    () async {
      final profile = await repository.updateProfile(
        'Juan',
        'alex@example.com',
      );
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['data'], {'full_name': 'Juan'});
      expect(body['email'], isNull);
      expect(profile.fullName, 'Juan');
    },
  );
  test('changing email preserves the old address until confirmation', () async {
    final profile = await repository.updateProfile('Juan', 'juan@example.com');
    expect(profile.email, 'alex@example.com');
    expect(profile.pendingEmail, 'juan@example.com');
    expect(jsonDecode(requests.single.body)['email'], 'juan@example.com');
  });
  test(
    'vehicle operations call the server functions with the correct data',
    () async {
      await repository.addVehicle(VehicleType.motorcycle, 'XYZ45D');
      await repository.selectVehicle('vehicle-1');
      await repository.deleteVehicle('vehicle-1');
      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/add_my_vehicle',
        '/rest/v1/rpc/select_my_vehicle',
        '/rest/v1/rpc/delete_my_vehicle',
      ]);
      expect(jsonDecode(requests.first.body), {
        'p_vehicle_type': 'motorcycle',
        'p_plate': 'XYZ45D',
      });
      expect(jsonDecode(requests.last.body), {'p_vehicle_id': 'vehicle-1'});
    },
  );
  test(
    'parking sends the selected vehicle and reads the persisted plate',
    () async {
      final sessions = SessionRepository(client);
      final session = await sessions.createSession(
        parkingId: 'parking-1',
        pickupTime: DateTime.utc(2026, 9, 30, 21),
        vehicleId: 'vehicle-1',
      );
      expect(jsonDecode(requests.last.body)['p_vehicle_id'], 'vehicle-1');
      expect(session.vehiclePlate, 'ABC123');
      await sessions.getActiveSession();
      expect(requests.last.url.queryParameters['user_id'], 'eq.user-1');
    },
  );
  test(
    'signing out clears the session and blocks subsequent vehicle writes',
    () async {
      await repository.signOut();
      expect(client.auth.currentUser, isNull);
      expect(requests.last.url.queryParameters['scope'], 'local');
      await expectLater(
        repository.addVehicle(VehicleType.car, 'ABC123'),
        throwsA(isA<AuthException>()),
      );
      expect(await SessionRepository(client).getActiveSession(), isNull);
    },
  );
}
