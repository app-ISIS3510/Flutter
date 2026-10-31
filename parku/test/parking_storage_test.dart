import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/data/local/app_database.dart';
import 'package:parku/data/local/parking_local_data_source.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/repositories/user_local_store.dart';
import 'package:parku/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/offline_fakes.dart';
import 'support/parking_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  final parking = Parking.fromMap({
    ...parkingData(),
    'image_url': 'https://parking.test/photo.jpg',
  });

  test(
    'new SQLite database stores the complete catalog and image URLs',
    () async {
      final db = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      addTearDown(db.close);
      final cache = ParkingLocalDataSource(database: db);
      await cache.saveParkingLots([parking]);
      await cache.saveParking(parking);
      expect(
        (await cache.readParkingLots())!.parkingLots.single.imageUrl,
        parking.imageUrl,
      );
      expect(
        (await cache.readParkingById(parking.id))!.parking.imageUrl,
        parking.imageUrl,
      );
      await cache.saveParkingLots([]);
      expect((await cache.readParkingLots())!.parkingLots, isEmpty);
    },
  );

  test(
    'upgrading a v4 SQLite cache preserves rows and adds both image columns',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'parku-cache-migration-',
      );
      final path = '${directory.path}/cache.db';
      final legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            for (final table in ['parking_cache', 'parking_detail_cache']) {
              await db.execute('''CREATE TABLE $table (
            id TEXT PRIMARY KEY, name TEXT, address TEXT, latitude REAL,
            longitude REAL, car_spaces INTEGER, motorcycle_spaces INTEGER,
            price_per_minute REAL, opening_time TEXT, closing_time TEXT,
            available_car_spaces INTEGER, available_motorcycle_spaces INTEGER,
            cached_at TEXT)''');
            }
            await db.execute(
              'CREATE TABLE cache_metadata (cache_key TEXT PRIMARY KEY, last_updated_at TEXT)',
            );
          },
        ),
      );
      final oldRow = {...parking.toMap(), 'cached_at': '2026-10-01T00:00:00Z'}
        ..remove('image_url');
      await legacy.insert('parking_cache', oldRow);
      await legacy.insert('cache_metadata', {
        'cache_key': 'parking_list',
        'last_updated_at': '2026-10-01T00:00:00Z',
      });
      await legacy.close();
      final database = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final cache = ParkingLocalDataSource(database: database);
      expect(
        (await cache.readParkingLots())!.parkingLots.single.name,
        parking.name,
      );
      await cache.saveParkingLots([parking]);
      await cache.saveParking(parking);
      await database.close();
      expect(
        (await cache.readParkingById(parking.id))!.parking.imageUrl,
        parking.imageUrl,
      );
      expect(await (await database.database).getVersion(), 5);
    },
  );

  test(
    'browser catalog and details survive reopening the preferences store',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = ParkingLocalDataSource(browserPreferences: preferences);
      await cache.saveParkingLots([parking]);
      await cache.saveParking(parking);
      await preferences.reload();
      final reopened = ParkingLocalDataSource(browserPreferences: preferences);
      expect(
        (await reopened.readParkingLots())!.parkingLots.single.id,
        parking.id,
      );
      expect(
        (await reopened.readParkingForNearby())!.parkingLots.single.imageUrl,
        parking.imageUrl,
      );
      expect(
        (await reopened.readParkingById(parking.id))!.parking.address,
        parking.address,
      );
      await reopened.removeParking(parking.id);
      expect((await reopened.readParkingForNearby())!.parkingLots, isEmpty);
    },
  );

  test(
    'browser confirmed session survives reopening and stays isolated by user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final client = offlineTestClient();
      addTearDown(client.dispose);
      await signInAs(client, 'user-1');
      final store = UserLocalStore(client, browserPreferences: preferences);
      await store.write('active_session', {
        'session': {
          'id': 'stay-1',
          'user_id': 'user-1',
          'parking_id': parking.id,
          'pickup_time': '2026-10-30T22:00:00Z',
          'started_at': '2026-10-30T18:00:00Z',
          'status': 'active',
        },
      });
      await preferences.reload();
      final remote = UnstableSessionRepository(client)..online = false;
      final service = SessionService(
        remote,
        store: UserLocalStore(client, browserPreferences: preferences),
      );
      expect((await service.getSavedActiveSession())!.id, 'stay-1');
      expect(remote.activeReads, 0);
      await signInAs(client, 'user-2');
      expect(await service.getSavedActiveSession(), isNull);
      expect(remote.activeReads, 0);
    },
  );
}
