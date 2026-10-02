import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/controllers/profile_controller.dart';
import 'package:parku/models/user_profile.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/services/driving_restriction_service.dart';
import 'package:parku/services/profile_service.dart';

import 'support/fake_user_repository.dart';

class DelayedRepository extends FakeUserRepository {
  final response = Completer<UserProfile>();
  @override
  Future<UserProfile> getProfile() => response.future;
}

void main() {
  test('validates each plate type and normalizes before saving', () async {
    final repository = FakeUserRepository();
    final service = ProfileService(repository);
    await service.addVehicle(VehicleType.car, ' abc123 ');
    await service.addVehicle(VehicleType.motorcycle, 'xyz45a');
    expect(repository.vehicles.map((v) => v.plate), ['ABC123', 'XYZ45A']);
    for (final plate in [
      '',
      'ABC12',
      'ABC-123',
      'ABC 123',
      '123ABC',
      'ABC12D',
    ]) {
      expect(
        () => service.addVehicle(VehicleType.car, plate),
        throwsFormatException,
      );
    }
    expect(
      () => service.addVehicle(VehicleType.motorcycle, 'ABC123'),
      throwsFormatException,
    );
    expect(repository.addCalls, 2);
  });
  test('validates name and email without saving invalid input', () async {
    final repository = FakeUserRepository();
    final service = ProfileService(repository);
    expect(
      () => service.updateProfile(' ', 'user@test.com'),
      throwsFormatException,
    );
    expect(() => service.updateProfile('Alex', 'user@'), throwsFormatException);
    await service.updateProfile(' Alex Rivera ', ' alex@example.com ');
    expect(repository.profile.fullName, 'Alex Rivera');
    expect(repository.profile.email, 'alex@example.com');
  });
  test('logout clears cached account information', () async {
    final repository = FakeUserRepository();
    final controller = ProfileController(ProfileService(repository));
    await controller.load();
    await controller.addVehicle(VehicleType.car, 'ABC123');
    expect(controller.selectedVehicle?.plate, 'ABC123');
    expect(await controller.signOut(), true);
    expect(controller.profile, isNull);
    expect(controller.vehicles, isEmpty);
    expect(repository.signedOut, true);
    controller.dispose();
  });
  test('a previous account response cannot return after logout', () async {
    final repository = DelayedRepository();
    final controller = ProfileController(ProfileService(repository));
    final loading = controller.load();
    controller.clear();
    repository.response.complete(repository.profile);
    await loading;
    expect(controller.profile, isNull);
    expect(controller.vehicles, isEmpty);
    controller.dispose();
  });
  test('failed saves leave the user data intact and allow retry', () async {
    final repository = FakeUserRepository();
    final controller = ProfileController(ProfileService(repository));
    await controller.load();
    repository.failure = Exception('offline');
    expect(await controller.addVehicle(VehicleType.car, 'ABC123'), false);
    expect(controller.busy, false);
    expect(controller.error, isNotNull);
    expect(controller.vehicles, isEmpty);
    repository.failure = null;
    expect(await controller.addVehicle(VehicleType.car, 'ABC123'), true);
    expect(controller.error, isNull);
    controller.dispose();
  });
  test('Bogotá restrictions use plate, type, local date, holidays and special days', () {
    final service = DrivingRestrictionService();
    const car = Vehicle(
      id: '1',
      type: VehicleType.car,
      plate: 'ABC123',
      isSelected: true,
    );
    const moto = Vehicle(
      id: '2',
      type: VehicleType.motorcycle,
      plate: 'ABC12D',
      isSelected: false,
    );
    expect(
      service.check(car, now: DateTime.utc(2026, 9, 8, 12)).restricted,
      true,
    );
    expect(
      service.check(car, now: DateTime.utc(2026, 9, 9, 12)).restricted,
      false,
    );
    expect(
      service.check(car, now: DateTime.utc(2026, 9, 9, 2)).restricted,
      true,
    );
    expect(
      service.check(moto, now: DateTime.utc(2026, 9, 8, 12)).restricted,
      false,
    );
    expect(
      service.check(car, now: DateTime.utc(2026, 9, 12, 12)).restricted,
      false,
    );
    expect(
      service.check(car, now: DateTime.utc(2026, 7, 20, 12)).restricted,
      false,
    );
    expect(
      service.check(moto, now: DateTime.utc(2026, 2, 5, 12)).hours,
      '5:00 AM–9:00 PM',
    );
    expect(
      service.check(car, now: DateTime.utc(2027, 9, 8, 12)).restricted,
      isNull,
    );
  });
}
