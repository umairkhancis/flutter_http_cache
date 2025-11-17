import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';

/// Abstract interface for cache storage backends
/// Implementations can be in-memory, disk-based, or combined
abstract class CacheStorage {
  /// Retrieves a cached entry by key
  /// Returns null if the entry doesn't exist
  Future<CacheEntry?> get(String key);

  /// Stores a cache entry
  /// Returns true if successful
  Future<bool> put(String key, CacheEntry entry);

  /// Removes a cache entry by key
  /// Returns true if the entry existed and was removed
  Future<bool> remove(String key);

  /// Checks if a key exists in the cache
  Future<bool> contains(String key);

  /// Removes all cache entries
  Future<void> clear();

  /// Removes all expired entries based on a predicate
  /// The predicate receives a CacheEntry and should return true if it should be removed
  Future<void> clearWhere(bool Function(CacheEntry entry) predicate);

  /// Gets all cache keys
  Future<List<String>> keys();

  /// Gets the number of entries in the cache
  Future<int> size();

  /// Gets the total size in bytes of cached data
  Future<int> sizeInBytes();

  /// Closes the storage and releases resources
  Future<void> close();
}
