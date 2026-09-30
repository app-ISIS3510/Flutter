import '../models/vehicle.dart';

class DrivingRestriction {
  final DateTime date;
  final bool? restricted;
  final String? hours;
  final String? explanation;
  const DrivingRestriction({
    required this.date,
    required this.restricted,
    this.hours,
    this.explanation,
  });
}

class DrivingRestrictionService {
  static const officialUrl = 'https://www.movilidadbogota.gov.co/pico-y-placa';

  // Calendario 2026. Mantener al día con la Secretaría de Movilidad.
  static const holidays2026 = {
    '01-01',
    '01-12',
    '03-23',
    '04-02',
    '04-03',
    '05-01',
    '05-18',
    '06-08',
    '06-15',
    '06-29',
    '07-20',
    '08-07',
    '08-17',
    '10-12',
    '11-02',
    '11-16',
    '12-08',
    '12-25',
  };

  DrivingRestriction check(Vehicle vehicle, {DateTime? now}) {
    // Bogotá usa UTC-5 todo el año; no depende de la zona del teléfono.
    final local = (now ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 5),
    );
    final date = DateTime.utc(local.year, local.month, local.day);
    if (date.year != 2026) {
      return DrivingRestriction(
        date: date,
        restricted: null,
        explanation: 'Check the updated calendar on the official website.',
      );
    }
    final dayKey =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    // Día sin carro y sin moto de 2026.
    if (dayKey == '02-05') {
      return DrivingRestriction(
        date: date,
        restricted: true,
        hours: '5:00 AM–9:00 PM',
        explanation: 'Car-free and motorcycle-free day.',
      );
    }
    if (vehicle.type == VehicleType.motorcycle ||
        date.weekday > 5 ||
        holidays2026.contains(dayKey)) {
      return DrivingRestriction(date: date, restricted: false);
    }
    final lastDigit = int.tryParse(
      vehicle.plate.substring(vehicle.plate.length - 1),
    );
    if (lastDigit == null) {
      return DrivingRestriction(date: date, restricted: null);
    }
    final firstGroup = lastDigit >= 1 && lastDigit <= 5;
    final restricted = date.day.isEven ? firstGroup : !firstGroup;
    return DrivingRestriction(
      date: date,
      restricted: restricted,
      hours: restricted ? '6:00 AM–9:00 PM' : null,
    );
  }
}
