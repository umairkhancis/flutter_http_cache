import 'package:flutter_http_cache/src/domain/service/cache_key_generator.dart';
import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:flutter_http_cache/src/data/storage.dart';

/// Handles cache invalidation on unsafe methods
/// Implements HTTP caching: - Invalidating Stored Responses
class CacheInvalidation {
  final CacheStorage _storage;

  CacheInvalidation(this._storage);

  /// Invalidates cache entries based on an unsafe method response
  /// HTTP caching: Invalidation of unsafe methods
  ///
  /// A cache MUST invalidate the target URI on successful response to:
  /// - PUT
  /// - POST
  /// - DELETE
  /// - PATCH
  ///
  /// May also invalidate URIs in Location and Content-Location headers
  Future<void> invalidateOnUnsafeMethod({
    required String method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> responseHeaders,
    required Map<String, String> requestHeaders,
  }) async {
    // Only invalidate on unsafe methods
    if (!HeaderUtils.isUnsafeMethod(method)) {
      return;
    }

    // Only invalidate on successful responses (2xx, 3xx)
    if (!_isSuccessfulResponse(statusCode)) {
      return;
    }

    // Invalidate target URI
    await _invalidateUri(uri, method, requestHeaders);

    // Optionally invalidate Location header URI
    final location = HeaderUtils.getHeader(responseHeaders, 'location');
    if (location != null) {
      final locationUri = Uri.tryParse(location);
      if (locationUri != null && _isSameOrigin(uri, locationUri)) {
        await _invalidateUri(locationUri, 'GET', requestHeaders);
      }
    }

    // Optionally invalidate Content-Location header URI
    final contentLocation =
        HeaderUtils.getHeader(responseHeaders, 'content-location');
    if (contentLocation != null) {
      final contentLocationUri = Uri.tryParse(contentLocation);
      if (contentLocationUri != null &&
          _isSameOrigin(uri, contentLocationUri)) {
        await _invalidateUri(contentLocationUri, 'GET', requestHeaders);
      }
    }
  }

  /// Invalidates a specific URI
  Future<void> _invalidateUri(
    Uri uri,
    String method,
    Map<String, String> requestHeaders,
  ) async {
    // Generate primary cache key
    final primaryKey = CacheKeyGenerator.generatePrimaryKey(method, uri);

    // Try to remove with primary key
    await _storage.remove(primaryKey);

    // Also try common Vary combinations
    // This is a best-effort approach since we don't know all possible Vary combinations
    final commonVaryHeaders = ['accept', 'accept-encoding', 'accept-language'];

    for (final varyHeader in commonVaryHeaders) {
      final varyKey = CacheKeyGenerator.generateVaryKey(
        method,
        uri,
        requestHeaders,
        varyHeader,
      );
      await _storage.remove(varyKey);
    }
  }

  /// Checks if response status indicates success
  bool _isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 400;
  }

  /// Checks if two URIs are same-origin (prevents cross-origin invalidation attacks)
  /// HTTP caching: Prevent cross-origin invalidation
  bool _isSameOrigin(Uri uri1, Uri uri2) {
    return uri1.scheme == uri2.scheme &&
        uri1.host == uri2.host &&
        uri1.port == uri2.port;
  }

  /// Marks an entry as invalid without removing it
  /// Useful for cases where you want to keep the entry but mark it stale
  Future<void> markAsInvalid(String cacheKey) async {
    final entry = await _storage.get(cacheKey);
    if (entry != null) {
      final invalidated = entry.copyWith(isInvalid: true);
      await _storage.put(cacheKey, invalidated);
    }
  }

  /// Invalidates all entries for a specific origin
  /// Useful for logout scenarios or when user data changes
  Future<void> invalidateOrigin(Uri origin) async {
    await _storage.clearWhere((entry) {
      return entry.uri.scheme == origin.scheme &&
          entry.uri.host == origin.host &&
          entry.uri.port == origin.port;
    });
  }

  /// Invalidates all entries matching a pattern
  /// Useful for invalidating specific API endpoints
  Future<void> invalidatePattern(bool Function(Uri uri) predicate) async {
    await _storage.clearWhere((entry) => predicate(entry.uri));
  }

  /// Clears all invalid entries
  Future<void> clearInvalidEntries() async {
    await _storage.clearWhere((entry) => entry.isInvalid);
  }
}
