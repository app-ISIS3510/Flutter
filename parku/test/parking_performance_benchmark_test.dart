import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/data/local/app_database.dart';
import 'package:parku/data/local/parking_local_data_source.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/models/smart_parking_result.dart';
import 'package:parku/services/smart_parking_processor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/parking_fakes.dart';

const warmupIterations = 10;
const measuredIterations = 100;
const catalogSizes = [4, 50, 500];

List<Parking> generateCatalog(int size) {
  return List.generate(
    size,
    (index) => Parking.fromMap(
      parkingData(
        id: 'parking-$index',
        name: 'Parking $index',
        latitude: 4.600 + (index % 20) * 0.0001,
        longitude: -74.1,
        carSpaces: 20,
        availableCarSpaces: index % 21,
      ),
    ),
  );
}

Future<List<SmartParkingResult>> processCatalog(List<Parking> parkingLots) {
  return processParkingCatalog(
    parkingLots: parkingLots,
    radiusMeters: 1000,
    isCar: true,
    latitude: 4.600,
    longitude: -74.1,
  );
}

Future<List<int>> measureOperation(Future<void> Function() operation) async {
  for (var i = 0; i < warmupIterations; i++) {
    await operation();
  }

  final measurements = <int>[];

  for (var i = 0; i < measuredIterations; i++) {
    final stopwatch = Stopwatch()..start();

    await operation();

    stopwatch.stop();

    measurements.add(stopwatch.elapsedMicroseconds);
  }

  return measurements;
}

void printStatistics(
  String operation,
  int catalogSize,
  List<int> measurements,
) {
  final sorted = [...measurements]..sort();

  final mean = sorted.reduce((a, b) => a + b) / sorted.length;

  final middle = sorted.length ~/ 2;

  final median = sorted.length.isEven
      ? (sorted[middle - 1] + sorted[middle]) / 2
      : sorted[middle].toDouble();

  final p95Index = (sorted.length * 0.95).ceil() - 1;
  final p95 = sorted[p95Index];

  // ignore: avoid_print
  print(
    'BENCHMARK | '
    'operation=$operation | '
    'lots=$catalogSize | '
    'iterations=${sorted.length} | '
    'mean=${mean.toStringAsFixed(2)} us | '
    'median=${median.toStringAsFixed(2)} us | '
    'p95=$p95 us',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Smart Parking performance', () {
    for (final size in catalogSizes) {
      test('Processes $size parking lots', () async {
        final catalog = generateCatalog(size);

        List<SmartParkingResult> results = [];

        final measurements = await measureOperation(() async {
          results = await processCatalog(catalog);
        });

        expect(results, hasLength(size));

        expect(results.where((item) => item.isRecommended), hasLength(1));

        printStatistics('smart_parking', size, measurements);
      });
    }
  });

  group('SQLite catalog write performance', () {
    for (final size in catalogSizes) {
      test('Stores $size parking lots', () async {
        final directory = await Directory.systemTemp.createTemp(
          'parku-performance-',
        );

        final database = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${directory.path}/benchmark.db',
        );

        addTearDown(() async {
          await database.close();
          await directory.delete(recursive: true);
        });

        final cache = ParkingLocalDataSource(database: database);

        final catalog = generateCatalog(size);

        await database.database;

        final measurements = await measureOperation(() async {
          await cache.saveParkingLots(catalog);
        });

        final saved = await cache.readParkingLots();

        expect(saved, isNotNull);
        expect(saved!.parkingLots, hasLength(size));

        printStatistics('sqlite_catalog_write', size, measurements);
      });
    }
  });

  group('SQLite cached catalog read performance', () {
    for (final size in catalogSizes) {
      test('Merges $size cached parking lots', () async {
        final directory = await Directory.systemTemp.createTemp(
          'parku-read-performance-',
        );

        final database = AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${directory.path}/benchmark.db',
        );

        addTearDown(() async {
          await database.close();
          await directory.delete(recursive: true);
        });

        final cache = ParkingLocalDataSource(database: database);
        final catalog = generateCatalog(size);

        final db = await database.database;

        await cache.saveParkingLots(catalog);

        final catalogTimestamp = DateTime.utc(2026, 11, 27);
        final detailTimestamp = catalogTimestamp.add(
          const Duration(minutes: 5),
        );

        await db.transaction((txn) async {
          await txn.update('parking_cache', {
            'cached_at': catalogTimestamp.toIso8601String(),
          });

          await txn.update(
            'cache_metadata',
            {'last_updated_at': catalogTimestamp.toIso8601String()},
            where: 'cache_key = ?',
            whereArgs: ['parking_list'],
          );

          final batch = txn.batch();

          for (var index = 0; index < size; index += 2) {
            batch.insert('parking_detail_cache', {
              ...catalog[index].toMap(),
              'name': 'Updated Parking $index',
              'cached_at': detailTimestamp.toIso8601String(),
            });
          }

          await batch.commit(noResult: true);
        });

        CachedParkingList? result;

        final measurements = await measureOperation(() async {
          result = await cache.readParkingForNearby();
        });

        expect(result, isNotNull);
        expect(result!.parkingLots, hasLength(size));
        expect(result!.cachedAt, catalogTimestamp);

        final byId = {
          for (final parking in result!.parkingLots) parking.id: parking,
        };

        for (var index = 0; index < size; index++) {
          final expectedName = index.isEven
              ? 'Updated Parking $index'
              : 'Parking $index';

          expect(byId['parking-$index']!.name, expectedName);
        }

        printStatistics('sqlite_cached_catalog_read', size, measurements);
      });
    }
  });
}
