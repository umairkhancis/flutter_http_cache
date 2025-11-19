import 'dart:developer' as developer;

import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:flutter_http_cache/src/domain/service/header_utils.dart';

/// Result type for cache interceptor operations
/// This is framework-agnostic and can be used by both HTTP and Dio interceptors
sealed class InterceptorResult {
  const InterceptorResult();
}

/// Return a cached response without making a network request
class CachedResult extends InterceptorResult {
  final CacheEntry entry;
  final int age;
  final bool isStale;
  final String? warning;

  const CachedResult({
    required this.entry,
    required this.age,
    required this.isStale,
    this.warning,
  });
}

/// Continue with network request (with optional validation headers)
class ContinueWithRequest extends InterceptorResult {
  final Map<String, String>? validationHeaders;
  final CacheEntry? cachedEntry;

  const ContinueWithRequest({
    this.validationHeaders,
    this.cachedEntry,
  });
}

/// Return an error response (e.g., 504 for cacheOnly policy)
class ErrorResult extends InterceptorResult {
  final int statusCode;
  final String message;
  final Map<String, String> headers;

  const ErrorResult({
    required this.statusCode,
    required this.message,
    required this.headers,
  });
}

/// Result of handling a network response
sealed class NetworkResponseResult {
  const NetworkResponseResult();
}

/// Use the updated cached entry (for 304 responses)
class UseUpdatedCache extends NetworkResponseResult {
  final CacheEntry entry;

  const UseUpdatedCache(this.entry);
}

/// Use the network response and store it
class UseNetworkResponse extends NetworkResponseResult {
  const UseNetworkResponse();
}

/// Result of handling network errors
sealed class NetworkErrorResult {
  const NetworkErrorResult();
}

/// Serve stale cache on error
class ServeStaleCache extends NetworkErrorResult {
  final CacheEntry entry;
  final int age;

  const ServeStaleCache({
    required this.entry,
    required this.age,
  });
}

/// Propagate the error
class PropagateError extends NetworkErrorResult {
  const PropagateError();
}

/// Shared service for HTTP cache interceptor logic
///
/// This service implements the Single Responsibility Principle by focusing
/// solely on caching decisions and operations. It's framework-agnostic and
/// can be used by any HTTP client interceptor.
///
/// **SOLID Principles Applied:**
/// - **S**ingle Responsibility: Only handles caching logic
/// - **O**pen/Closed: Extensible through result types
/// - **L**iskov Substitution: Can be used by any interceptor
/// - **I**nterface Segregation: Clean, focused methods
/// - **D**ependency Inversion: Depends on HttpCache abstraction
class CacheInterceptorService {
  final HttpCache cache;

  CacheInterceptorService(this.cache);

  /// Handles cache lookup for incoming requests
  ///
  /// Returns:
  /// - [CachedResult] if cache hit and can serve
  /// - [ContinueWithRequest] if need to make network request
  /// - [ErrorResult] for cacheOnly policy misses
  Future<InterceptorResult> handleRequest({
    required String method,
    required Uri uri,
    required Map<String, String> requestHeaders,
    CachePolicy? cachePolicy,
  }) async {
    cachePolicy ??= CachePolicy.standard;

    if (cache.config.enableLogging) {
      developer.log(
        'CacheInterceptorService.handleRequest: $method $uri (policy: ${cachePolicy.name})',
        name: 'flutter_http_cache',
      );
    }

    // For networkOnly and networkFirst policies, skip cache lookup
    if (cachePolicy == CachePolicy.networkOnly ||
        cachePolicy == CachePolicy.networkFirst) {
      return const ContinueWithRequest();
    }

    // Try to get from cache
    final cachedResponse = await cache.get(
      method: method,
      uri: uri,
      requestHeaders: requestHeaders,
      policy: cachePolicy,
    );

    if (cachedResponse != null) {
      if (!cachedResponse.requiresValidation) {
        // Cache hit - return cached response
        if (cache.config.enableLogging) {
          developer.log(
            'CacheInterceptorService: Cache ${cachedResponse.isStale ? "HIT-STALE" : "HIT"} (age: ${cachedResponse.age}s)',
            name: 'flutter_http_cache',
          );
        }

        return CachedResult(
          entry: cachedResponse.entry,
          age: cachedResponse.age,
          isStale: cachedResponse.isStale,
        );
      } else {
        // Cache hit but requires validation
        if (cache.config.enableLogging) {
          developer.log(
            'CacheInterceptorService: Cache entry requires validation',
            name: 'flutter_http_cache',
          );
        }

        final validationHeaders = cache.generateValidationHeaders(
          cachedResponse.entry,
          requestHeaders,
        );

        return ContinueWithRequest(
          validationHeaders: validationHeaders,
          cachedEntry: cachedResponse.entry,
        );
      }
    }

    // Cache miss for cacheOnly policy
    if (cachePolicy == CachePolicy.cacheOnly) {
      if (cache.config.enableLogging) {
        developer.log(
          'CacheInterceptorService: Cache MISS with cacheOnly policy',
          name: 'flutter_http_cache',
        );
      }

      return const ErrorResult(
        statusCode: 504,
        message: 'Cache Miss - only-if-cached',
        headers: {'x-cache': 'MISS'},
      );
    }

    // Continue with network request
    return const ContinueWithRequest();
  }

  /// Handles network response storage and 304 handling
  ///
  /// Returns:
  /// - [UseUpdatedCache] if 304 response with updated entry
  /// - [UseNetworkResponse] for normal responses
  Future<NetworkResponseResult> handleResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> requestHeaders,
    required Map<String, String> responseHeaders,
    required List<int> body,
    required DateTime requestTime,
    required DateTime responseTime,
    CacheEntry? cachedEntry,
  }) async {
    if (cache.config.enableLogging) {
      developer.log(
        'CacheInterceptorService.handleResponse: Network response received (status: $statusCode)',
        name: 'flutter_http_cache',
      );
    }

    // Check if this was a validation request (304 response)
    if (statusCode == 304 && cachedEntry != null) {
      // Not Modified - update cached entry
      final updated = await cache.updateFrom304(
        method: method,
        uri: uri,
        requestHeaders: requestHeaders,
        response304Headers: responseHeaders,
        validationRequestTime: requestTime,
        validationResponseTime: responseTime,
      );

      if (updated != null) {
        if (cache.config.enableLogging) {
          developer.log(
            'CacheInterceptorService: 304 response - serving updated cached entry',
            name: 'flutter_http_cache',
          );
        }

        return UseUpdatedCache(updated);
      }
    }

    // Store the response in cache if appropriate
    await cache.put(
      method: method,
      uri: uri,
      statusCode: statusCode,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      body: body,
      requestTime: requestTime,
      responseTime: responseTime,
    );

    // Invalidate on unsafe methods
    if (HeaderUtils.isUnsafeMethod(method)) {
      await cache.invalidateOnUnsafeMethod(
        method: method,
        uri: uri,
        statusCode: statusCode,
        requestHeaders: requestHeaders,
        responseHeaders: responseHeaders,
      );
    }

    return const UseNetworkResponse();
  }

  /// Handles network errors with stale cache fallback
  ///
  /// Returns:
  /// - [ServeStaleCache] if stale cache available and allowed
  /// - [PropagateError] if no cache or not allowed to serve stale
  Future<NetworkErrorResult> handleError({
    required String method,
    required Uri uri,
    required Map<String, String> requestHeaders,
    CachePolicy? cachePolicy,
  }) async {
    if (cache.config.enableLogging) {
      developer.log(
        'CacheInterceptorService.handleError: Network request failed',
        name: 'flutter_http_cache',
      );
    }

    // Network error - try to serve stale if allowed
    if (cache.config.serveStaleOnError ||
        cachePolicy == CachePolicy.networkFirst) {
      final cachedResponse = await cache.get(
        method: method,
        uri: uri,
        requestHeaders: requestHeaders,
        policy: CachePolicy.cacheFirst,
      );

      if (cachedResponse != null) {
        if (cache.config.enableLogging) {
          developer.log(
            'CacheInterceptorService: Serving stale cache on error',
            name: 'flutter_http_cache',
          );
        }

        return ServeStaleCache(
          entry: cachedResponse.entry,
          age: cachedResponse.age,
        );
      }
    }

    // No stale response available - propagate error
    return const PropagateError();
  }

  /// Creates headers for a cached response
  Map<String, String> createCachedResponseHeaders(
    CacheEntry entry,
    int age,
    bool isStale, {
    String? warning,
  }) {
    var headers = Map<String, String>.from(entry.headers);

    // Add Age header
    headers['age'] = age.toString();

    // Add warning if stale
    if (isStale || warning != null) {
      headers = HeaderUtils.addStaleWarning(
        headers,
        message: warning ?? '111 - "Revalidation Failed"',
      );
    }

    // Add X-Cache header for debugging
    headers['x-cache'] = isStale ? 'HIT-STALE' : 'HIT';

    return headers;
  }
}
