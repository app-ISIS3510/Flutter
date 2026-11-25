class LfuCache<K, V> {
  final int capacity;
  final _entries = <K, _Entry<V>>{};

  LfuCache(this.capacity) : assert(capacity > 0);

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    entry.accesses++;
    return entry.value;
  }

  void put(K key, V value) {
    final previous = _entries[key];
    if (previous != null) {
      previous.value = value;
      return;
    }
    if (_entries.length == capacity) {
      // Iteration order keeps the oldest insertion first when frequencies tie.
      final victim = _entries.entries.reduce(
        (first, next) =>
            first.value.accesses <= next.value.accesses ? first : next,
      );
      _entries.remove(victim.key);
    }
    _entries[key] = _Entry(value);
  }

  void remove(K key) => _entries.remove(key);

  void clear() => _entries.clear();
}

class _Entry<V> {
  V value;
  int accesses = 1;

  _Entry(this.value);
}
