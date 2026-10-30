import 'dart:collection';

/// Bounded in-memory storage, ordered from least to most recently accessed.
/// Reads and writes promote an entry; peeks and background updates do not.
class LruCache<K extends Object, V extends Object> {
  final int capacity;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  LruCache({required this.capacity}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive.');
    }
  }

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;

  /// A snapshot; callers cannot mutate the cache through this list.
  List<K> get keys => List<K>.unmodifiable(_entries.keys);

  V? get(K key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  V? peek(K key) => _entries[key];

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void updateIfPresent(K key, V value) {
    if (_entries.containsKey(key)) _entries[key] = value;
  }

  V? remove(K key) => _entries.remove(key);

  void clear() => _entries.clear();
}
