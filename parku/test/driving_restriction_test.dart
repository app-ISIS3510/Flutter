import 'package:flutter_test/flutter_test.dart';
import 'package:parku/models/vehicle.dart';
import 'package:parku/services/driving_restriction_service.dart';

Vehicle car(String plate) =>
    Vehicle(id: 'car', type: VehicleType.car, plate: plate);

void main() {
  final service = DrivingRestrictionService();

  test('checks every plate ending on even and odd weekdays', () {
    for (var digit = 0; digit <= 9; digit++) {
      final vehicle = car('ABC12$digit');
      expect(
        service.check(vehicle, now: DateTime.utc(2026, 10, 8, 15)).restricted,
        [1, 2, 3, 4, 5].contains(digit),
        reason: 'Even day, plate ending in $digit',
      );
      expect(
        service.check(vehicle, now: DateTime.utc(2026, 10, 9, 15)).restricted,
        [6, 7, 8, 9, 0].contains(digit),
        reason: 'Odd day, plate ending in $digit',
      );
    }
  });

  test('uses the Bogotá date at the UTC day boundary', () {
    final vehicle = car('ABC123');
    final beforeMidnight = service.check(
      vehicle,
      now: DateTime.utc(2026, 10, 9, 4, 59),
    );
    final midnight = service.check(vehicle, now: DateTime.utc(2026, 10, 9, 5));
    expect(beforeMidnight.date, DateTime.utc(2026, 10, 8));
    expect(beforeMidnight.restricted, isTrue);
    expect(midnight.date, DateTime.utc(2026, 10, 9));
    expect(midnight.restricted, isFalse);
    expect(
      service
          .check(vehicle, now: DateTime.parse('2026-10-08T23:59:00-05:00'))
          .restricted,
      beforeMidnight.restricted,
    );
  });

  test('reports the restriction for the day even outside restricted hours', () {
    for (final hour in [5, 11, 20]) {
      final result = service.check(
        car('ABC126'),
        now: DateTime.utc(2026, 10, 9, hour),
      );
      expect(result.restricted, isTrue);
      expect(result.hours, '6:00 AM–9:00 PM');
    }
    expect(
      service
          .check(car('ABC126'), now: DateTime.utc(2026, 10, 10, 3))
          .restricted,
      isTrue,
    );
  });

  test('weekends, holidays and motorcycles have no regular pico y placa', () {
    for (final date in [
      DateTime.utc(2026, 10, 10, 15),
      DateTime.utc(2026, 10, 11, 15),
      DateTime.utc(2026, 10, 12, 15),
    ]) {
      expect(service.check(car('ABC123'), now: date).restricted, isFalse);
      expect(service.check(car('ABC126'), now: date).restricted, isFalse);
    }
    const motorcycle = Vehicle(
      id: 'moto',
      type: VehicleType.motorcycle,
      plate: 'ABC12D',
    );
    expect(
      service.check(motorcycle, now: DateTime.utc(2026, 10, 9, 15)).restricted,
      isFalse,
    );
    expect(
      service.check(motorcycle, now: DateTime.utc(2026, 2, 5, 15)).restricted,
      isTrue,
    );
  });

  test('invalid plates and an unsupported calendar give an unknown result', () {
    for (final plate in ['', 'ABC', 'ABC12D', 'ABC1A6']) {
      expect(
        service
            .check(car(plate), now: DateTime.utc(2026, 10, 9, 15))
            .restricted,
        isNull,
      );
    }
    expect(
      service
          .check(car(' abc126 '), now: DateTime.utc(2026, 10, 9, 15))
          .restricted,
      isTrue,
    );
    expect(
      service
          .check(car('ABC126'), now: DateTime.utc(2027, 10, 8, 15))
          .restricted,
      isNull,
    );
  });
}
