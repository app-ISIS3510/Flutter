import 'package:flutter_test/flutter_test.dart';
import 'package:parku/services/smart_parking_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> parking({
    required String id,
    required String name,
    double? latitude = 4.601,
    double? longitude = -74.065,
    int carSpaces = 20,
    int availableCarSpaces = 8,
  }) {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'car_spaces': carSpaces,
      'motorcycle_spaces': 10,
      'available_car_spaces': availableCarSpaces,
      'available_motorcycle_spaces': 7,
    };
  }

  test('processes parking data in an isolate', () async {
    final input = SmartParkingProcessingInput(
      parkingLots: [
        parking(id: 'low', name: 'Low availability', availableCarSpaces: 2),
        parking(id: 'high', name: 'High availability', availableCarSpaces: 15),
      ],
      radiusMeters: 1000,
      isCar: true,
      latitude: 4.600,
      longitude: -74.065,
    );

    final results = await processSmartParkingInIsolate(input);

    expect(results, hasLength(2));
    expect((results.first['parking'] as Map<String, dynamic>)['id'], 'high');
    expect(results.first['percentage'], 75.0);
    expect(results.first['recommended'], isTrue);
    expect(results.last['recommended'], isFalse);
  });

  test('works without location or recommendations', () async {
    final input = SmartParkingProcessingInput(
      parkingLots: [
        parking(id: 'b', name: 'B Parking', latitude: null),
        parking(id: 'a', name: 'A Parking'),
      ],
      radiusMeters: 500,
      isCar: true,
      latitude: null,
      longitude: null,
    );

    final results = await processSmartParkingInIsolate(input);

    expect(results, hasLength(2));
    expect((results.first['parking'] as Map<String, dynamic>)['id'], 'a');
    expect(results.every((item) => item['distance'] == null), isTrue);
    expect(results.every((item) => item['recommended'] == false), isTrue);
  });

  test('excludes parking lots outside the radius', () async {
    final input = SmartParkingProcessingInput(
      parkingLots: [
        parking(id: 'near', name: 'Near', latitude: 4.601),
        parking(id: 'far', name: 'Far', latitude: 4.65),
      ],
      radiusMeters: 500,
      isCar: true,
      latitude: 4.600,
      longitude: -74.065,
    );

    final results = await processSmartParkingInIsolate(input);

    expect(results, hasLength(1));
    expect((results.single['parking'] as Map<String, dynamic>)['id'], 'near');
  });
  test('processes 150 parking lots using compute', () async {
    final parkingLots = List.generate(
      150,
      (index) => parking(
        id: 'parking-$index',
        name: 'Parking $index',
        availableCarSpaces: index % 21,
      ),
    );

    final input = SmartParkingProcessingInput(
      parkingLots: parkingLots,
      radiusMeters: 1000,
      isCar: true,
      latitude: 4.600,
      longitude: -74.065,
    );

    final results = await processSmartParkingInIsolate(input);

    expect(results, hasLength(150));
    expect(results.first['percentage'], 100.0);
    expect(results.first['recommended'], isTrue);
    expect(results.where((item) => item['recommended'] == true), hasLength(1));
  });
}
