import 'dart:developer' as developer;

import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:http/http.dart' as http;

import 'http_client.dart';
import 'http_client_factory.dart';

/// HTTP cache interceptor for http package
/// Intercepts HTTP requests and responses to provide caching
class HttpCacheInterceptor {
  final HttpCache cache;
  final HttpClient httpExecutor;

  HttpCacheInterceptor({
    required this.cache,
  }) : httpExecutor = HttpClientFactory.create(cache.config.httpClientType);

  /// Sends an HTTP request with caching
  Future<http.Response> send(
    http.Request request, {
    CachePolicy? cachePolicy,
  }) async {
    final method = request.method;
    final uri = request.url;
    final requestHeaders = request.headers;

    // Determine effective cache policy
    cachePolicy ??= CachePolicy.standard;

    if (cache.config.enableLogging) {
      developer.log(
        'CachedHttpClient.send: $method $uri (policy: ${cachePolicy.name})',
        name: 'flutter_http_cache',
      );
    }

    // For networkOnly and networkFirst policies, skip cache lookup
    if (cachePolicy != CachePolicy.networkOnly &&
        cachePolicy != CachePolicy.networkFirst) {
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
              'CachedHttpClient: Cache ${cachedResponse.isStale ? "HIT-STALE" : "HIT"} (age: ${cachedResponse.age}s)',
              name: 'flutter_http_cache',
            );
          }
          return _createResponseFromCache(
            cachedResponse.entry,
            cachedResponse.age,
            cachedResponse.isStale,
          );
        } else {
          // Cache hit but requires validation
          if (cache.config.enableLogging) {
            developer.log(
              'CachedHttpClient: Cache entry requires validation',
              name: 'flutter_http_cache',
            );
          }
          return await _validateAndReturn(
            request,
            cachedResponse.entry,
            cachePolicy,
          );
        }
      }

      // Cache miss for cacheOnly policy
      if (cachePolicy == CachePolicy.cacheOnly) {
        if (cache.config.enableLogging) {
          developer.log(
            'CachedHttpClient: Cache MISS with cacheOnly policy',
            name: 'flutter_http_cache',
          );
        }
        return http.Response(
          '',
          504, // Gateway Timeout
          headers: {'x-cache': 'MISS'},
          reasonPhrase: 'Cache Miss - only-if-cached',
        );
      }
    }

    // Make network request
    try {
      if (cache.config.enableLogging) {
        developer.log(
          'CachedHttpClient: Making network request',
          name: 'flutter_http_cache',
        );
      }
      final requestTime = DateTime.now();
      final response = await httpExecutor.send(request);
      final responseTime = DateTime.now();

      if (cache.config.enableLogging) {
        developer.log(
          'CachedHttpClient: Network response received (status: ${response.statusCode}, size: ${response.bodyBytes.length} bytes)',
          name: 'flutter_http_cache',
        );
      }

      // Store in cache if appropriate
      await _storeResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        requestHeaders: requestHeaders,
        responseHeaders: response.headers,
        body: response.bodyBytes,
        requestTime: requestTime,
        responseTime: responseTime,
      );

      // Invalidate on unsafe methods
      if (HeaderUtils.isUnsafeMethod(method)) {
        await cache.invalidateOnUnsafeMethod(
          method: method,
          uri: uri,
          statusCode: response.statusCode,
          requestHeaders: requestHeaders,
          responseHeaders: response.headers,
        );
      }

      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: _addAgeHeader(response.headers, 0),
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      developer.log(
        'CachedHttpClient: Network request failed: $e',
        name: 'flutter_http_cache',
        error: e,
      );

      if (cache.config.enableLogging) {
        developer.log(
          'CachedHttpClient: Network request failed: $e',
          name: 'flutter_http_cache',
          error: e,
        );
      }
      // Network error - try to serve stale if allowed
      // For networkFirst policy, always try to serve stale on error
      if (cache.config.serveStaleOnError ||
          cachePolicy == CachePolicy.networkFirst) {
        final cachedResponse = await cache.get(
          method: method,
          uri: uri,
          requestHeaders: requestHeaders,
          policy: CachePolicy.cacheFirst,
        );

        if (cachedResponse != null) {
          return _createResponseFromCache(
            cachedResponse.entry,
            cachedResponse.age,
            true, // isStale
            warning: '111 - "Revalidation Failed"',
          );
        }
      }

      // Rethrow if no stale response available
      rethrow;
    }
  }

  /// Validates a cached response and returns updated response
  Future<http.Response> _validateAndReturn(
    http.Request originalRequest,
    CacheEntry cachedEntry,
    CachePolicy cachePolicy,
  ) async {
    // Generate validation headers
    final validationHeaders = cache.generateValidationHeaders(
      cachedEntry,
      originalRequest.headers,
    );

    // Create validation request
    final validationRequest = http.Request(
      originalRequest.method,
      originalRequest.url,
    )..headers.addAll(validationHeaders);

    try {
      final requestTime = DateTime.now();
      final response = await httpExecutor.send(validationRequest);
      final responseTime = DateTime.now();

      if (response.statusCode == 304) {
        // Not Modified - update cached entry and return it
        final updated = await cache.updateFrom304(
          method: originalRequest.method,
          uri: originalRequest.url,
          requestHeaders: originalRequest.headers,
          response304Headers: response.headers,
          validationRequestTime: requestTime,
          validationResponseTime: responseTime,
        );

        if (updated != null) {
          return _createResponseFromCache(updated, 0, false);
        }
      } else {
        // Full response - store and return
        final body = response.bodyBytes;

        await _storeResponse(
          method: originalRequest.method,
          uri: originalRequest.url,
          statusCode: response.statusCode,
          requestHeaders: originalRequest.headers,
          responseHeaders: response.headers,
          body: body,
          requestTime: requestTime,
          responseTime: responseTime,
        );

        return http.Response.bytes(
          body,
          response.statusCode,
          headers: _addAgeHeader(response.headers, 0),
          reasonPhrase: response.reasonPhrase,
        );
      }
    } catch (e) {
      // Validation failed - serve stale if allowed
      if (cache.config.serveStaleOnError) {
        return _createResponseFromCache(
          cachedEntry,
          cachedEntry.ageHeader ?? 0,
          true,
          warning: '111 - "Revalidation Failed"',
        );
      }
      rethrow;
    }

    // Fallback
    return _createResponseFromCache(
        cachedEntry, cachedEntry.ageHeader ?? 0, false);
  }

  /// Stores a response in the cache
  Future<void> _storeResponse({
    required String method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> requestHeaders,
    required Map<String, String> responseHeaders,
    required List<int> body,
    required DateTime requestTime,
    required DateTime responseTime,
  }) async {
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
  }

  /// Creates an HTTP response from a cached entry
  http.Response _createResponseFromCache(
    CacheEntry entry,
    int age,
    bool isStale, {
    String? warning,
  }) {
    var headers = Map<String, String>.from(entry.headers);

    // Add Age header
    headers = _addAgeHeader(headers, age);

    // Add warning if stale
    if (isStale || warning != null) {
      headers = HeaderUtils.addStaleWarning(
        headers,
        message: warning,
      );
    }

    // Add X-Cache header for debugging
    headers['x-cache'] = isStale ? 'HIT-STALE' : 'HIT';

    return http.Response.bytes(
      entry.body,
      entry.statusCode,
      headers: headers,
    );
  }

  /// Adds Age header to response
  Map<String, String> _addAgeHeader(Map<String, String> headers, int age) {
    final updated = Map<String, String>.from(headers);
    updated['age'] = age.toString();
    return updated;
  }

  /// Closes the interceptor and underlying client
  void close() {
    httpExecutor.close();
  }
}
