import 'package:flutter_http_cache/src/data/storage.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/eviction_strategy.dart';
import 'package:synchronized/synchronized.dart';

/// In-memory cache storage with LRU eviction
/// Thread-safe implementation using synchronized locks
class MemoryStorage implements CacheStorage {
  final int _maxEntries;
  final int _maxBytes;
  final EvictionStrategy _evictionStrategy;

  final _lock = Lock();
  final _cache = <String, _CacheValue>{};
  final _accessOrder = <String, DateTime>{};
  final _accessCount = <String, int>{};
  int _currentBytes = 0;

  MemoryStorage({
    int maxEntries = 100,
    int maxBytes = 10 * 1024 * 1024, // 10MB default
    EvictionStrategy evictionStrategy = EvictionStrategy.lru,
  })  : _maxEntries = maxEntries,
        _maxBytes = maxBytes,
        _evictionStrategy = evictionStrategy;

  @override
  Future<CacheEntry?> get(String key) async {
    return _lock.synchronized(() {
      final value = _cache[key];
      if (value == null) return null;

      // Update access metrics
      _accessOrder[key] = DateTime.now();
      _accessCount[key] = (_accessCount[key] ?? 0) + 1;

      return value.entry;
    });
  }

  @override
  Future<bool> put(String key, CacheEntry entry) async {
    return _lock.synchronized(() {
      final entrySize = _calculateEntrySize(entry);

      // Check if adding this entry would exceed max bytes
      if (entrySize > _maxBytes) {
        return false; // Entry too large
      }

      // Remove old entry if exists
      final existingValue = _cache[key];
      if (existingValue != null) {
        _currentBytes -= existingValue.size;
      }

      // Evict entries if necessary
      while (_shouldEvict(entrySize)) {
        final keyToEvict = _selectEvictionCandidate();
        if (keyToEvict == null) break;
        _removeEntry(keyToEvict);
      }

      // Add new entry
      _cache[key] = _CacheValue(entry, entrySize);
      _currentBytes += entrySize;
      _accessOrder[key] = DateTime.now();
      _accessCount[key] = 1;

      return true;
    });
  }

  @override
  Future<bool> remove(String key) async {
    return _lock.synchronized(() {
      return _removeEntry(key);
    });
  }

  @override
  Future<bool> contains(String key) async {
    return _lock.synchronized(() {
      return _cache.containsKey(key);
    });
  }

  @override
  Future<void> clear() async {
    return _lock.synchronized(() {
      _cache.clear();
      _accessOrder.clear();
      _accessCount.clear();
      _currentBytes = 0;
    });
  }

  @override
  Future<void> clearWhere(bool Function(CacheEntry entry) predicate) async {
    return _lock.synchronized(() {
      final keysToRemove = <String>[];

      for (final entry in _cache.entries) {
        if (predicate(entry.value.entry)) {
          keysToRemove.add(entry.key);
        }
      }

      for (final key in keysToRemove) {
        _removeEntry(key);
      }
    });
  }

  @override
  Future<List<String>> keys() async {
    return _lock.synchronized(() {
      return _cache.keys.toList();
    });
  }

  @override
  Future<int> size() async {
    return _lock.synchronized(() {
      return _cache.length;
    });
  }

  @override
  Future<int> sizeInBytes() async {
    return _lock.synchronized(() {
      return _currentBytes;
    });
  }

  @override
  Future<void> close() async {
    await clear();
  }

  /// Calculates the size of an entry in bytes
  int _calculateEntrySize(CacheEntry entry) {
    int size = 0;

    // Body size
    size += entry.body.length;

    // Headers size (approximate)
    for (final header in entry.headers.entries) {
      size += header.key.length + header.value.length;
    }

    // URI and method
    size += entry.uri.toString().length;
    size += entry.method.length;

    // Vary headers
    if (entry.varyHeaders != null) {
      for (final header in entry.varyHeaders!.entries) {
        size += header.key.length + header.value.length;
      }
    }

    return size;
  }

  /// Checks if eviction is needed
  bool _shouldEvict(int newEntrySize) {
    return _cache.length >= _maxEntries ||
        (_currentBytes + newEntrySize) > _maxBytes;
  }

  /// Selects a candidate for eviction based on strategy
  String? _selectEvictionCandidate() {
    if (_cache.isEmpty) return null;

    switch (_evictionStrategy) {
      case EvictionStrategy.lru:
        return _selectLRU();
      case EvictionStrategy.lfu:
        return _selectLFU();
      case EvictionStrategy.fifo:
        return _selectFIFO();
      case EvictionStrategy.ttl:
        return _selectTTL();
    }
  }

  /// Selects Least Recently Used entry
  String? _selectLRU() {
    if (_accessOrder.isEmpty) return _cache.keys.first;

    DateTime? oldestTime;
    String? oldestKey;

    for (final entry in _accessOrder.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    return oldestKey;
  }

  /// Selects Least Frequently Used entry
  String? _selectLFU() {
    if (_accessCount.isEmpty) return _cache.keys.first;

    int? lowestCount;
    String? lfuKey;

    for (final entry in _accessCount.entries) {
      if (lowestCount == null || entry.value < lowestCount) {
        lowestCount = entry.value;
        lfuKey = entry.key;
      }
    }

    return lfuKey;
  }

  /// Selects First In First Out entry
  String? _selectFIFO() {
    return _cache.keys.first;
  }

  /// Selects entry closest to expiration
  String? _selectTTL() {
    // For TTL, we would need to calculate freshness
    // For now, fallback to LRU
    return _selectLRU();
  }

  /// Removes an entry and updates metrics
  bool _removeEntry(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _currentBytes -= value.size;
      _accessOrder.remove(key);
      _accessCount.remove(key);
      return true;
    }
    return false;
  }
}

/// Internal wrapper for cache values
class _CacheValue {
  final CacheEntry entry;
  final int size;

  _CacheValue(this.entry, this.size);
}
