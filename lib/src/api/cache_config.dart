import 'package:flutter_http_cache/src/data/storage.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_type.dart';
import 'package:flutter_http_cache/src/domain/valueobject/eviction_strategy.dart';
import 'package:flutter_http_cache/src/domain/valueobject/http_client_type.dart';

/// Configuration for the HTTP cache
class CacheConfig {
  // Storage limits
  final int maxMemorySize;
  final int maxMemoryEntries;
  final int maxDiskSize;
  final int maxDiskEntries;

  // Cache type
  final CacheType cacheType;

  // Eviction strategy
  final EvictionStrategy evictionStrategy;

  // Behavior options
  final bool enableHeuristicFreshness;
  final double heuristicFreshnessPercent;
  final Duration maxHeuristicFreshness;

  // Stale handling
  final bool serveStaleOnError;
  final Duration maxStaleAge;

  // Privacy
  final bool doubleKeyCache;

  // Database path (for disk storage)
  final String? databasePath;

  // Custom storage backend
  final CacheStorage? customStorage;

  // Debug options
  final bool enableLogging;

  // HTTP client implementation
  final HttpClientType httpClientType;

  const CacheConfig({
    this.maxMemorySize = 10 * 1024 * 1024, // 10MB
    this.maxMemoryEntries = 100,
    this.maxDiskSize = 50 * 1024 * 1024, // 50MB
    this.maxDiskEntries = 1000,
    this.cacheType = CacheType.private,
    this.evictionStrategy = EvictionStrategy.lru,
    this.enableHeuristicFreshness = true,
    this.heuristicFreshnessPercent = 0.10, // 10%
    this.maxHeuristicFreshness = const Duration(days: 7),
    this.serveStaleOnError = true,
    this.maxStaleAge = const Duration(days: 1),
    this.doubleKeyCache = false,
    this.databasePath,
    this.customStorage,
    this.enableLogging = false,
    this.httpClientType = HttpClientType.defaultHttp,
  });

  CacheConfig copyWith({
    int? maxMemorySize,
    int? maxMemoryEntries,
    int? maxDiskSize,
    int? maxDiskEntries,
    CacheType? cacheType,
    EvictionStrategy? evictionStrategy,
    bool? enableHeuristicFreshness,
    double? heuristicFreshnessPercent,
    Duration? maxHeuristicFreshness,
    bool? serveStaleOnError,
    Duration? maxStaleAge,
    bool? doubleKeyCache,
    String? databasePath,
    CacheStorage? customStorage,
    bool? enableLogging,
    bool? useDio,
  }) {
    return CacheConfig(
      maxMemorySize: maxMemorySize ?? this.maxMemorySize,
      maxMemoryEntries: maxMemoryEntries ?? this.maxMemoryEntries,
      maxDiskSize: maxDiskSize ?? this.maxDiskSize,
      maxDiskEntries: maxDiskEntries ?? this.maxDiskEntries,
      cacheType: cacheType ?? this.cacheType,
      evictionStrategy: evictionStrategy ?? this.evictionStrategy,
      enableHeuristicFreshness:
          enableHeuristicFreshness ?? this.enableHeuristicFreshness,
      heuristicFreshnessPercent:
          heuristicFreshnessPercent ?? this.heuristicFreshnessPercent,
      maxHeuristicFreshness:
          maxHeuristicFreshness ?? this.maxHeuristicFreshness,
      serveStaleOnError: serveStaleOnError ?? this.serveStaleOnError,
      maxStaleAge: maxStaleAge ?? this.maxStaleAge,
      doubleKeyCache: doubleKeyCache ?? this.doubleKeyCache,
      databasePath: databasePath ?? this.databasePath,
      customStorage: customStorage ?? this.customStorage,
      enableLogging: enableLogging ?? this.enableLogging,
      httpClientType: httpClientType,
    );
  }
}
