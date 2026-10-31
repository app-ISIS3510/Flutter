import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku/data/local/parking_local_data_source.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/repositories/parking_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/parking_fakes.dart';

class FakeParkingCache extends ParkingLocalDataSource {
  CachedParkingList? cached;

  @override
  Future<CachedParkingList?> readParkingForNearby() async => cached;
}

void main() {
  late SupabaseClient client;
  late FakeParkingCache cache;
  late ParkingRepository repository;
  late int networkRequests;
  late bool networkAvailable;

  setUp(() {
    networkRequests = 0;
    networkAvailable = true;
    cache = FakeParkingCache();

    client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        networkRequests++;

        if (!networkAvailable) {
          throw Exception('No internet connection');
        }

        return http.Response(
          jsonEncode([parkingData(id: 'network-1', name: 'Network Parking')]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    repository = ParkingRepository(client, localDataSource: cache);
  });

  tearDown(() async {
    await client.dispose();
  });

  test('searches cached parking by name without internet', () async {
    networkAvailable = false;

    cache.cached = CachedParkingList(
      parkingLots: [
        Parking.fromMap(parkingData(id: '1', name: 'City U Parking')),
        Parking.fromMap(parkingData(id: '2', name: 'Library Parking')),
      ],
      cachedAt: DateTime.now(),
    );

    final result = await repository.searchParkingLotsWithSource('city');

    expect(result.parkingLots, hasLength(1));
    expect(result.parkingLots.first.name, 'City U Parking');
    expect(result.isFromCache, isTrue);
    expect(result.updatedAt, isNotNull);
    expect(networkRequests, greaterThanOrEqualTo(1));
  });

  test('searches cached parking by address ignoring case', () async {
    networkAvailable = false;

    final parking = parkingData(id: '1', name: 'University Parking');

    parking['address'] = 'Carrera 7 Bogotá';

    cache.cached = CachedParkingList(
      parkingLots: [Parking.fromMap(parking)],
      cachedAt: DateTime.now(),
    );

    final results = await repository.searchParkingLots('carrera 7');

    expect(results, hasLength(1));
    expect(results.first.name, 'University Parking');
    expect(networkRequests, greaterThanOrEqualTo(1));
  });

  test('uses network when no cached catalog exists', () async {
    final results = await repository.searchParkingLots('network');

    expect(results, hasLength(1));
    expect(results.first.name, 'Network Parking');
    expect(networkRequests, 1);
  });

  test('throws when cache is missing and network is unavailable', () async {
    networkAvailable = false;

    await expectLater(repository.searchParkingLots('city'), throwsException);

    expect(networkRequests, greaterThanOrEqualTo(1));
  });

  test('returns no matches from existing cache without network', () async {
    networkAvailable = false;

    cache.cached = CachedParkingList(
      parkingLots: [
        Parking.fromMap(parkingData(id: '1', name: 'City U Parking')),
      ],
      cachedAt: DateTime.now(),
    );

    final results = await repository.searchParkingLots('airport');

    expect(results, isEmpty);
    expect(networkRequests, greaterThanOrEqualTo(1));
  });
}
