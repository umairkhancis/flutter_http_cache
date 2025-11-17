import 'dart:developer' as developer;

import 'package:flutter_http_cache/src/api/cache_config.dart';
import 'package:flutter_http_cache/src/domain/service/cache_key_generator.dart';
import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:flutter_http_cache/src/data/impl/combined_storage.dart';
import 'package:flutter_http_cache/src/data/impl/disk_storage.dart';
import 'package:flutter_http_cache/src/data/impl/memory_storage.dart';
import 'package:flutter_http_cache/src/data/storage.dart';
import 'package:flutter_http_cache/src/domain/service/age_calculator.dart';
import 'package:flutter_http_cache/src/domain/service/cache_policy.dart';
import 'package:flutter_http_cache/src/domain/service/freshness.dart';
import 'package:flutter_http_cache/src/domain/service/heuristic.dart';
import 'package:flutter_http_cache/src/domain/service/invalidation.dart';
import 'package:flutter_http_cache/src/domain/service/validator.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_control.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_policy.dart';
import 'package:flutter_http_cache/src/domain/valueobject/http_cache_request.dart';
import 'package:flutter_http_cache/src/domain/valueobject/http_cache_response.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Main HTTP cache implementation
/// HTTP caching standard compliant caching for HTTP requests and responses
class HttpCache {
  final CacheConfig config;
  late final CacheStorage _storage;
  late final FreshnessCalculator _freshnessCalculator;
  late final CachePolicyDecisions _policyDecisions;
  late final CacheInvalidation _invalidation;
  late final CacheValidator _validator;

  bool _initialized = false;

  HttpCache({required this.config}) {
    _initializeComponents();
  }

  void _initializeComponents() {
    _policyDecisions = CachePolicyDecisions(cacheType: config.cacheType);
    _validator = CacheValidator();

    final heuristicCalculator = HeuristicFreshnessCalculator(
      enabled: config.enableHeuristicFreshness,
      percentage: config.heuristicFreshnessPercent,
      maxDuration: config.maxHeuristicFreshness,
    );

    _freshnessCalculator = FreshnessCalculator(
      heuristicCalculator: heuristicCalculator,
      cacheType: config.cacheType,
    );
  }

  /// Initializes the cache (must be called before use)
  Future<void> initialize() async {
    if (_initialized) return;

    if (config.customStorage != null) {
      _storage = config.customStorage!;
    } else {
      // Create combined storage with memory + disk
      final memoryStorage = MemoryStorage(
        maxEntries: config.maxMemoryEntries,
        maxBytes: config.maxMemorySize,
        evictionStrategy: config.evictionStrategy,
      );

      // Determine database path
      String dbPath;
      if (config.databasePath != null) {
        dbPath = config.databasePath!;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        dbPath = path.join(appDir.path, 'http_cache.db');
      }

      final diskStorage = DiskStorage(
        dbPath: dbPath,
        maxEntries: config.maxDiskEntries,
        maxBytes: config.maxDiskSize,
        evictionStrategy: config.evictionStrategy,
      );

      final combinedStorage = CombinedStorage(
        memoryCache: memoryStorage,
        diskCache: diskStorage,
      );

      await combinedStorage.initialize();
      _storage = combinedStorage;
    }

    _invalidation = CacheInvalidation(_storage);
    _initialized = true;
  }

  /// Gets a cached response if available and usable
  Future<CachedResponse?> get({
    required String method,
    required Uri uri,
    required Map<String, String> requestHeaders,
    CachePolicy? policy,
  }) async {
    await initialize();

    if (config.enableLogging) {
      developer.log(
        'Cache.get: $method $uri (policy: ${policy?.name ?? "standard"})',
        name: 'flutter_http_cache',
      );
    }

    final requestCacheControl = CacheControl.parse(
      HeaderUtils.getHeader(requestHeaders, 'cache-control'),
      isRequest: true,
    );

    // Handle only-if-cached
    if (requestCacheControl.onlyIfCached) {
      policy = CachePolicy.cacheOnly;
    }

    // Generate cache key
    final cacheKey = _generateCacheKey(method, uri, requestHeaders, null);

    // Try to get from cache
    final entry = await _storage.get(cacheKey);
    if (entry == null) {
      if (config.enableLogging) {
        developer.log(
          'Cache.get: MISS - no cached entry found',
          name: 'flutter_http_cache',
        );
      }
      return null;
    }

    if (config.enableLogging) {
      developer.log(
        'Cache.get: Found cached entry (statusCode: ${entry.statusCode})',
        name: 'flutter_http_cache',
      );
    }

    // Parse response cache control
    final responseCacheControl = CacheControl.parse(
      entry.getHeader('cache-control'),
      isRequest: false,
    );

    // Check if entry can be reused
    final reusability = _policyDecisions.canReuse(
      entry: entry,
      requestMethod: method,
      requestUri: uri,
      requestHeaders: requestHeaders,
      requestCacheControl: requestCacheControl,
      responseCacheControl: responseCacheControl,
      isFresh: _freshnessCalculator.isFresh(entry, responseCacheControl),
      varyHeaderValue: entry.getHeader('vary'),
    );

    if (!reusability.isReusable && !reusability.needsValidation) {
      return null;
    }

    // Check freshness
    final isFresh = _freshnessCalculator.isFresh(entry, responseCacheControl);

    if (isFresh) {
      // Fresh response, can be used directly
      return CachedResponse(
        entry: entry,
        requiresValidation: false,
        age: AgeCalculator.calculateAgeInSeconds(entry),
      );
    }

    // Stale response
    if (policy == CachePolicy.cacheFirst || policy == CachePolicy.cacheOnly) {
      // Serve stale for these policies
      return CachedResponse(
        entry: entry,
        requiresValidation: false,
        isStale: true,
        age: AgeCalculator.calculateAgeInSeconds(entry),
      );
    }

    // Requires validation
    if (reusability.needsValidation || !isFresh) {
      return CachedResponse(
        entry: entry,
        requiresValidation: true,
        isStale: !isFresh,
        age: AgeCalculator.calculateAgeInSeconds(entry),
      );
    }

    return null;
  }

  /// Stores a response in the cache
  Future<bool> put({
    required String method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> requestHeaders,
    required Map<String, String> responseHeaders,
    required List<int> body,
    required DateTime requestTime,
    required DateTime responseTime,
  }) async {
    await initialize();

    final requestCacheControl = CacheControl.parse(
      HeaderUtils.getHeader(requestHeaders, 'cache-control'),
      isRequest: true,
    );

    final responseCacheControl = CacheControl.parse(
      HeaderUtils.getHeader(responseHeaders, 'cache-control'),
      isRequest: false,
    );

    // Check if response can be stored
    final storability = _policyDecisions.canStore(
      method: method,
      statusCode: statusCode,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      requestCacheControl: requestCacheControl,
      responseCacheControl: responseCacheControl,
    );

    if (!storability.storable) {
      if (config.enableLogging) {
        developer.log(
          'Not storing response: ${storability.reason}',
          name: 'flutter_http_cache',
        );
      }
      return false;
    }

    // Filter prohibited headers
    final filteredHeaders =
        HeaderUtils.filterProhibitedHeaders(responseHeaders);

    // Extract Vary headers if present
    final varyHeaderValue = HeaderUtils.getHeader(responseHeaders, 'vary');
    final varyHeaders = CacheKeyGenerator.extractVaryHeaders(
      varyHeaderValue,
      requestHeaders,
    );

    // Generate cache key
    final cacheKey = _generateCacheKey(
      method,
      uri,
      requestHeaders,
      null,
    );

    // Create cache entry
    final entry = CacheEntry(
      method: method,
      uri: uri,
      statusCode: statusCode,
      headers: filteredHeaders,
      body: body,
      responseTime: responseTime,
      requestTime: requestTime,
      varyHeaders: varyHeaders,
    );

    // Store in cache
    return await _storage.put(cacheKey, entry);
  }

  /// Updates a cached entry from a 304 Not Modified response
  Future<CacheEntry?> updateFrom304({
    required String method,
    required Uri uri,
    required Map<String, String> requestHeaders,
    required Map<String, String> response304Headers,
    required DateTime validationRequestTime,
    required DateTime validationResponseTime,
  }) async {
    await initialize();

    final cacheKey = _generateCacheKey(method, uri, requestHeaders, null);
    final entry = await _storage.get(cacheKey);

    if (entry == null) return null;

    final updated = _validator.updateFrom304(
      entry,
      response304Headers,
      validationResponseTime,
      validationRequestTime,
    );

    await _storage.put(cacheKey, updated);
    return updated;
  }

  /// Invalidates cache on unsafe methods
  Future<void> invalidateOnUnsafeMethod({
    required String method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> requestHeaders,
    required Map<String, String> responseHeaders,
  }) async {
    await initialize();

    await _invalidation.invalidateOnUnsafeMethod(
      method: method,
      uri: uri,
      statusCode: statusCode,
      responseHeaders: responseHeaders,
      requestHeaders: requestHeaders,
    );
  }

  /// Generates validation headers for a cached entry
  Map<String, String> generateValidationHeaders(
    CacheEntry entry,
    Map<String, String> originalHeaders,
  ) {
    return _validator.generateValidationHeaders(entry, originalHeaders);
  }

  /// Clears the entire cache
  Future<void> clear() async {
    await initialize();
    await _storage.clear();
  }

  /// Clears expired entries
  Future<void> clearExpired() async {
    await initialize();

    await _storage.clearWhere((entry) {
      final cacheControl = CacheControl.parse(
        entry.getHeader('cache-control'),
        isRequest: false,
      );

      final isFresh = _freshnessCalculator.isFresh(entry, cacheControl);
      return !isFresh;
    });
  }

  /// Gets cache statistics
  Future<Map<String, dynamic>> getStats() async {
    await initialize();

    final size = await _storage.size();
    final sizeBytes = await _storage.sizeInBytes();

    return {
      'entries': size,
      'bytes': sizeBytes,
      'bytesFormatted': _formatBytes(sizeBytes),
      'cacheUsage': _formatDiskCacheUsage(sizeBytes),
    };
  }

  // ========================================================================
  // SIMPLIFIED API - Using Value Objects (Recommended)
  // ========================================================================

  /// Gets a cached response using a request object
  ///
  /// This is the simplified version of [get] that uses value objects
  /// to reduce parameter count and improve code clarity.
  ///
  /// Example:
  /// ```dart
  /// final request = HttpCacheRequest.get(
  ///   Uri.parse('https://api.example.com/data'),
  ///   policy: CachePolicy.standard,
  /// );
  /// final cached = await cache.getWithRequest(request);
  /// ```
  Future<CachedResponse?> getWithRequest(HttpCacheRequest request) async {
    return get(
      method: request.method,
      uri: request.uri,
      requestHeaders: request.headers,
      policy: request.policy,
    );
  }

  /// Stores a response using request and response objects
  ///
  /// This is the simplified version of [put] that uses value objects
  /// to reduce parameter count and improve code clarity.
  ///
  /// Example:
  /// ```dart
  /// final request = HttpCacheRequest.get(uri);
  /// final response = HttpCacheResponse.fromHttpResponse(
  ///   httpResponse,
  ///   requestTime: requestTime,
  ///   responseTime: responseTime,
  /// );
  /// await cache.putWithRequest(request, response);
  /// ```
  Future<bool> putWithRequest(
    HttpCacheRequest request,
    HttpCacheResponse response,
  ) async {
    return put(
      method: request.method,
      uri: request.uri,
      statusCode: response.statusCode,
      requestHeaders: request.headers,
      responseHeaders: response.headers,
      body: response.body,
      requestTime: response.requestTime,
      responseTime: response.responseTime,
    );
  }

  /// Updates a cached entry from a 304 response using request and response objects
  ///
  /// Example:
  /// ```dart
  /// final updated = await cache.updateFrom304WithRequest(
  ///   request,
  ///   response304,
  /// );
  /// ```
  Future<CacheEntry?> updateFrom304WithRequest(
    HttpCacheRequest request,
    HttpCacheResponse response304,
  ) async {
    return updateFrom304(
      method: request.method,
      uri: request.uri,
      requestHeaders: request.headers,
      response304Headers: response304.headers,
      validationRequestTime: response304.requestTime,
      validationResponseTime: response304.responseTime,
    );
  }

  /// Invalidates cache on unsafe methods using request and response objects
  ///
  /// Example:
  /// ```dart
  /// await cache.invalidateWithRequest(postRequest, postResponse);
  /// ```
  Future<void> invalidateWithRequest(
    HttpCacheRequest request,
    HttpCacheResponse response,
  ) async {
    return invalidateOnUnsafeMethod(
      method: request.method,
      uri: request.uri,
      statusCode: response.statusCode,
      requestHeaders: request.headers,
      responseHeaders: response.headers,
    );
  }

  // ========================================================================

  /// Closes the cache and releases resources
  Future<void> close() async {
    if (_initialized) {
      await _storage.close();
      _initialized = false;
    }
  }

  String _generateCacheKey(
    String method,
    Uri uri,
    Map<String, String> requestHeaders,
    String? varyHeaderValue,
  ) {
    if (varyHeaderValue != null) {
      final referringSite = config.doubleKeyCache
          ? uri.host // Use host as referring site
          : null;

      return CacheKeyGenerator.generateVaryKey(
        method,
        uri,
        requestHeaders,
        varyHeaderValue,
        referringSite: referringSite,
      );
    }

    return CacheKeyGenerator.generatePrimaryKey(method, uri);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDiskCacheUsage(int bytes) {
    return "${(bytes / config.maxDiskSize * 100).toStringAsFixed(2)}% of ${_formatBytes(config.maxDiskSize)}";
  }
}

/// Represents a cached response
class CachedResponse {
  final CacheEntry entry;
  final bool requiresValidation;
  final bool isStale;
  final int age;

  const CachedResponse({
    required this.entry,
    required this.requiresValidation,
    this.isStale = false,
    required this.age,
  });
}
