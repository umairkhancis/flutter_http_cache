import 'package:flutter_http_cache/src/data/impl/disk_storage.dart';
import 'package:flutter_http_cache/src/data/impl/memory_storage.dart';
import 'package:flutter_http_cache/src/data/storage.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';

/// Combined storage that uses both memory (L1) and disk (L2) caches
/// Provides fast in-memory access with persistent disk backup
class CombinedStorage implements CacheStorage {
  final MemoryStorage _memoryCache;
  final DiskStorage _diskCache;

  CombinedStorage({
    required MemoryStorage memoryCache,
    required DiskStorage diskCache,
  })  : _memoryCache = memoryCache,
        _diskCache = diskCache;

  /// Initializes the storage (required for disk cache)
  Future<void> initialize() async {
    await _diskCache.initialize();
  }

  @override
  Future<CacheEntry?> get(String key) async {
    // Try memory first (L1 cache)
    var entry = await _memoryCache.get(key);
    if (entry != null) {
      return entry;
    }

    // Try disk (L2 cache)
    entry = await _diskCache.get(key);
    if (entry != null) {
      // Promote to memory cache
      await _memoryCache.put(key, entry);
      return entry;
    }

    return null;
  }

  @override
  Future<bool> put(String key, CacheEntry entry) async {
    // Write to both caches
    // Memory cache first (fast access)
    final memoryResult = await _memoryCache.put(key, entry);

    // Disk cache (persistence)
    final diskResult = await _diskCache.put(key, entry);

    // Consider successful if at least one succeeded
    return memoryResult || diskResult;
  }

  @override
  Future<bool> remove(String key) async {
    // Remove from both caches
    final memoryResult = await _memoryCache.remove(key);
    final diskResult = await _diskCache.remove(key);

    return memoryResult || diskResult;
  }

  @override
  Future<bool> contains(String key) async {
    // Check memory first
    if (await _memoryCache.contains(key)) {
      return true;
    }

    // Check disk
    return await _diskCache.contains(key);
  }

  @override
  Future<void> clear() async {
    // Clear both caches
    await _memoryCache.clear();
    await _diskCache.clear();
  }

  @override
  Future<void> clearWhere(bool Function(CacheEntry entry) predicate) async {
    // Clear from both caches
    await _memoryCache.clearWhere(predicate);
    await _diskCache.clearWhere(predicate);
  }

  @override
  Future<List<String>> keys() async {
    // Get keys from disk (authoritative source)
    final diskKeys = await _diskCache.keys();
    final memoryKeys = await _memoryCache.keys();

    // Combine and deduplicate
    final allKeys = <String>{...diskKeys, ...memoryKeys};
    return allKeys.toList();
  }

  @override
  Future<int> size() async {
    // Return disk size (authoritative)
    return await _diskCache.size();
  }

  @override
  Future<int> sizeInBytes() async {
    // Return combined size
    final diskSize = await _diskCache.sizeInBytes();

    // Note: This might double-count entries in both caches
    // For accurate measurement, we'd need to check for duplicates
    return diskSize; // Return disk size as it's more accurate
  }

  @override
  Future<void> close() async {
    await _memoryCache.close();
    await _diskCache.close();
  }

  /// Clears only the memory cache, leaving disk intact
  /// Useful for memory pressure situations
  Future<void> clearMemoryCache() async {
    await _memoryCache.clear();
  }

  /// Clears only expired entries from both caches
  Future<void> clearExpired(bool Function(CacheEntry entry) isExpired) async {
    await clearWhere(isExpired);
  }

  /// Gets memory cache statistics
  Future<CacheStats> getStats() async {
    final memorySize = await _memoryCache.size();
    final memorySizeBytes = await _memoryCache.sizeInBytes();
    final diskSize = await _diskCache.size();
    final diskSizeBytes = await _diskCache.sizeInBytes();

    return CacheStats(
      memoryEntries: memorySize,
      memoryBytes: memorySizeBytes,
      diskEntries: diskSize,
      diskBytes: diskSizeBytes,
    );
  }
}

/// Cache statistics
class CacheStats {
  final int memoryEntries;
  final int memoryBytes;
  final int diskEntries;
  final int diskBytes;

  const CacheStats({
    required this.memoryEntries,
    required this.memoryBytes,
    required this.diskEntries,
    required this.diskBytes,
  });

  @override
  String toString() {
    return 'CacheStats(memory: $memoryEntries entries, ${_formatBytes(memoryBytes)}, '
        'disk: $diskEntries entries, ${_formatBytes(diskBytes)})';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
