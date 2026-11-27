import 'package:flutter_test/flutter_test.dart';
import 'package:parku/data/memory/favorite_memory_cache.dart';
import 'package:parku/models/parking.dart';
import 'package:parku/state/favorite_list_state.dart';

import 'support/parking_fakes.dart';

void main() {
  late FavoriteMemoryCache cache;

  final parking = Parking.fromMap(parkingData());

  setUp(() {
    cache = FavoriteMemoryCache();
  });

  FavoriteListState createSnapshot() {
    return FavoriteListState(
      favorites: [parking],
      updatedAt: DateTime.now().toUtc(),
      pendingCount: 0,
    );
  }

  test('returns null on cache miss', () {
    expect(cache.read('user-1'), isNull);
  });

  test('returns stored snapshot on cache hit', () {
    cache.selectUser('user-1');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: cache.generation,
    );

    final result = cache.read('user-1');

    expect(result, isNotNull);
    expect(result!.favorites.single.id, parking.id);
    expect(result.isFromCache, isTrue);
  });

  test('invalidates cached snapshot after a mutation', () {
    cache.selectUser('user-1');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: cache.generation,
    );

    cache.invalidate('user-1');

    expect(cache.read('user-1'), isNull);
  });

  test('prevents stale reads from repopulating the cache', () {
    cache.selectUser('user-1');

    final previousGeneration = cache.generation;

    cache.invalidate('user-1');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: previousGeneration,
    );

    expect(cache.read('user-1'), isNull);
  });

  test('does not share cached snapshots between users', () {
    cache.selectUser('user-1');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: cache.generation,
    );

    expect(cache.read('user-2'), isNull);
    expect(cache.read('user-1'), isNull);
  });

  test('rejects writes from a previous user session', () {
    cache.selectUser('user-1');

    final previousGeneration = cache.generation;

    cache.selectUser('user-2');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: previousGeneration,
    );

    expect(cache.read('user-1'), isNull);
  });

  test('protects the cached favorites list from mutation', () {
    cache.selectUser('user-1');

    final snapshot = createSnapshot();

    cache.write('user-1', snapshot, expectedGeneration: cache.generation);

    snapshot.favorites.clear();

    final cached = cache.read('user-1')!;

    expect(cached.favorites, hasLength(1));

    expect(() => cached.favorites.clear(), throwsUnsupportedError);
  });

  test('clears cached data when requested', () {
    cache.selectUser('user-1');

    cache.write(
      'user-1',
      createSnapshot(),
      expectedGeneration: cache.generation,
    );

    cache.clear();

    expect(cache.read('user-1'), isNull);
  });
}
