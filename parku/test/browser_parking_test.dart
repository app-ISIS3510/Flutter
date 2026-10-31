@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:parku/data/local/parking_local_data_source.dart';
import 'package:parku/models/parking.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

import 'support/parking_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesPlugin.registerWith(null);

  test(
    'web default cache persists real browser storage without SQLite',
    () async {
      final preferences = await SharedPreferences.getInstance();
      const key = 'parku.parking_cache.v1';
      await preferences.remove(key);
      addTearDown(() => preferences.remove(key));
      final parking = Parking.fromMap({
        ...parkingData(),
        'image_url': 'https://parking.test/browser.jpg',
      });
      final cache = ParkingLocalDataSource();
      await cache.saveParkingLots([parking]);

      final savedAt = (await cache.readParkingLots())!.cachedAt;

      await preferences.reload();
      final reopened = ParkingLocalDataSource();
      final restored = await reopened.readParkingLots();

      expect(restored, isNotNull);
      expect(restored!.cachedAt, savedAt);
      expect(
        (await reopened.readParkingForNearby())!.parkingLots.single.name,
        parking.name,
      );
      expect(
        (await reopened.readParkingById(parking.id))!.parking.imageUrl,
        parking.imageUrl,
      );
      expect(preferences.getString(key), contains(parking.id));
    },
  );
}
