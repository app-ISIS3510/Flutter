import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/vehicle.dart';

abstract class UserRepository {
  Future<UserProfile> getProfile();
  Future<UserProfile> updateProfile(String name, String email);
  Future<List<Vehicle>> getVehicles();
  Future<void> addVehicle(VehicleType type, String plate);
  Future<void> selectVehicle(String id);
  Future<void> deleteVehicle(String id);
  Future<bool> isAdmin();
  Future<void> signOut();
}

class SupabaseUserRepository implements UserRepository {
  final SupabaseClient client;
  SupabaseUserRepository(this.client);

  String get _userId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Sign in to continue.');
    return id;
  }

  UserProfile _profile(User user) => UserProfile(
    id: user.id,
    fullName:
        (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '')
            as String,
    email: user.email ?? '',
    pendingEmail: user.newEmail,
  );

  @override
  Future<bool> isAdmin() async {
    final response = await client
        .from('app_admins')
        .select('user_id')
        .eq('user_id', _userId)
        .maybeSingle();

    return response != null;
  }

  @override
  Future<UserProfile> getProfile() async {
    _userId;
    final response = await client.auth.getUser();
    if (response.user == null) {
      throw const AuthException('Sign in to continue.');
    }
    return _profile(response.user!);
  }

  @override
  Future<UserProfile> updateProfile(String name, String email) async {
    _userId;
    // Supabase confirma el correo nuevo antes de reemplazar el correo actual.
    final response = await client.auth.updateUser(
      UserAttributes(
        data: {'full_name': name},
        email: email == client.auth.currentUser?.email ? null : email,
      ),
    );
    if (response.user == null) {
      throw const AuthException('Sign in to continue.');
    }
    return _profile(response.user!);
  }

  @override
  Future<List<Vehicle>> getVehicles() async {
    final rows = await client
        .from('vehicles')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return rows.map(Vehicle.fromMap).toList();
  }

  @override
  Future<void> addVehicle(VehicleType type, String plate) async {
    _userId;
    await client.rpc(
      'add_my_vehicle',
      params: {'p_vehicle_type': type.value, 'p_plate': plate},
    );
  }

  @override
  Future<void> selectVehicle(String id) async {
    _userId;
    await client.rpc('select_my_vehicle', params: {'p_vehicle_id': id});
  }

  @override
  Future<void> deleteVehicle(String id) async {
    _userId;
    await client.rpc('delete_my_vehicle', params: {'p_vehicle_id': id});
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);
}
