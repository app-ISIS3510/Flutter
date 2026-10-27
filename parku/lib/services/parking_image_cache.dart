import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ParkingImageCache {
  static final instance = CacheManager(
    Config(
      'parking_photos',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 30,
    ),
  );
}
