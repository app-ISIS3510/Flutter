import 'dart:math';
import 'dart:io';

import 'package:parku/data/memory/lru_cache.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  for (final capacity in [0, -1]) {
    var rejected = false;
    try {
      LruCache<String, int>(capacity: capacity);
    } on ArgumentError {
      rejected = true;
    }
    check(rejected, 'A nonpositive capacity must be rejected.');
  }

  final cache = LruCache<String, int>(capacity: 2);
  cache.put('A', 1);
  cache.put('B', 2);
  check(cache.get('A') == 1, 'A recently viewed detail must be returned.');
  cache.put('C', 3);
  check(cache.peek('B') == null, 'Reading A must protect it from eviction.');
  check(cache.keys.join(',') == 'A,C', 'The oldest entry must be first.');
  cache.put('A', 4);
  check(
    cache.length == 2 && cache.keys.join(',') == 'C,A',
    'Replacing a value promotes it without growing the cache.',
  );
  cache.updateIfPresent('C', 5);
  check(
    cache.peek('C') == 5 && cache.keys.join(',') == 'C,A',
    'A background catalog update must preserve access order.',
  );
  cache.updateIfPresent('missing', 99);
  check(
    cache.length == 2,
    'Background updates must not prefill unvisited details.',
  );
  cache.get('missing');
  cache.put('D', 6);
  check(
    cache.peek('C') == null && cache.peek('A') == 4,
    'A miss must not change the eviction decision.',
  );
  final snapshot = cache.keys;
  cache.clear();
  check(
    snapshot.length == 2 && cache.isEmpty,
    'Keys must be a detached snapshot.',
  );
  var immutable = false;
  try {
    snapshot.add('bad');
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Callers must not mutate internal access order.');

  // Compare the hash-based implementation against a separate list-based model.
  final random = Random(3510);
  for (final capacity in [1, 2, 20]) {
    final actual = LruCache<String, int>(capacity: capacity);
    final values = <String, int>{};
    final order = <String>[];
    for (var i = 0; i < 5000; i++) {
      final key = 'parking-${random.nextInt(30)}';
      final value = random.nextInt(1000);
      switch (random.nextInt(5)) {
        case 0:
          actual.put(key, value);
          order.remove(key);
          order.add(key);
          values[key] = value;
          if (order.length > capacity) values.remove(order.removeAt(0));
        case 1:
          check(actual.get(key) == values[key], 'Read mismatch.');
          if (values.containsKey(key)) {
            order.remove(key);
            order.add(key);
          }
        case 2:
          check(actual.peek(key) == values[key], 'Peek mismatch.');
        case 3:
          actual.updateIfPresent(key, value);
          if (values.containsKey(key)) values[key] = value;
        case 4:
          check(actual.remove(key) == values.remove(key), 'Removal mismatch.');
          order.remove(key);
      }
      check(actual.length <= capacity, 'Capacity exceeded.');
      check(actual.keys.join(',') == order.join(','), 'LRU order mismatch.');
      for (final key in order) {
        check(actual.peek(key) == values[key], 'Stored value mismatch.');
      }
    }
  }
  stdout.writeln(
    'LRU checks passed: eviction, recency, replacement, background updates, '
    'clearing and 15000 model-checked operations.',
  );
}
