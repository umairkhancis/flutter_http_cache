import 'dart:developer' as developer;

import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:flutter_http_cache/src/domain/service/cache_interceptor_service.dart';
import 'package:http/http.dart' as http;

import 'http_client.dart';
import 'http_client_factory.dart';

/// HTTP cache interceptor for http package
/// Intercepts HTTP requests and responses to provide caching
///
/// This is a thin adapter that uses [CacheInterceptorService] for all caching logic,
/// following the Dependency Inversion Principle.
class HttpCacheInterceptor {
  final HttpCache cache;
  final HttpClient httpExecutor;
  late final CacheInterceptorService _service;

  HttpCacheInterceptor({
    required this.cache,
  }) : httpExecutor = HttpClientFactory.create(cache.config.httpClientType) {
    _service = CacheInterceptorService(cache);
  }

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
        'HttpCacheInterceptor.send: $method $uri (policy: ${cachePolicy.name})',
        name: 'flutter_http_cache',
      );
    }

    // Delegate cache lookup to service
    final result = await _service.handleRequest(
      method: method,
      uri: uri,
      requestHeaders: requestHeaders,
      cachePolicy: cachePolicy,
    );

    return switch (result) {
      // Cache hit - return cached response
      CachedResult() => _createResponseFromCachedResult(result),

      // Continue with network request (possibly with validation)
      ContinueWithRequest() => await _executeNetworkRequest(
          request,
          cachePolicy,
          result.validationHeaders,
          result.cachedEntry,
        ),

      // Cache miss with cacheOnly policy
      ErrorResult() => http.Response(
          '',
          result.statusCode,
          headers: result.headers,
          reasonPhrase: result.message,
        ),
    };
  }

  /// Executes a network request and handles the response
  Future<http.Response> _executeNetworkRequest(
    http.Request originalRequest,
    CachePolicy cachePolicy,
    Map<String, String>? validationHeaders,
    CacheEntry? cachedEntry,
  ) async {
    try {
      // Create request with validation headers if provided
      final request = http.Request(
        originalRequest.method,
        originalRequest.url,
      )..headers.addAll(originalRequest.headers);

      if (validationHeaders != null) {
        request.headers.addAll(validationHeaders);
      }

      if (cache.config.enableLogging) {
        developer.log(
          'HttpCacheInterceptor: Making network request',
          name: 'flutter_http_cache',
        );
      }

      final requestTime = DateTime.now();
      final response = await httpExecutor.send(request);
      final responseTime = DateTime.now();

      if (cache.config.enableLogging) {
        developer.log(
          'HttpCacheInterceptor: Network response received (status: ${response.statusCode}, size: ${response.bodyBytes.length} bytes)',
          name: 'flutter_http_cache',
        );
      }

      // Delegate response handling to service
      final result = await _service.handleResponse(
        method: originalRequest.method,
        uri: originalRequest.url,
        statusCode: response.statusCode,
        requestHeaders: originalRequest.headers,
        responseHeaders: response.headers,
        body: response.bodyBytes,
        requestTime: requestTime,
        responseTime: responseTime,
        cachedEntry: cachedEntry,
      );

      return switch (result) {
        // 304 response - use updated cache
        UseUpdatedCache() => _createResponseFromCache(
            result.entry,
            0,
            false,
          ),

        // Normal response - use network response
        UseNetworkResponse() => http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: _addAgeHeader(response.headers, 0),
            reasonPhrase: response.reasonPhrase,
          ),
      };
    } catch (e) {
      developer.log(
        'HttpCacheInterceptor: Network request failed: $e',
        name: 'flutter_http_cache',
        error: e,
      );

      // Delegate error handling to service
      final errorResult = await _service.handleError(
        method: originalRequest.method,
        uri: originalRequest.url,
        requestHeaders: originalRequest.headers,
        cachePolicy: cachePolicy,
      );

      return switch (errorResult) {
        // Serve stale cache on error
        ServeStaleCache() => _createResponseFromCache(
            errorResult.entry,
            errorResult.age,
            true,
            warning: '111 - "Revalidation Failed"',
          ),

        // Propagate error
        PropagateError() => throw e,
      };
    }
  }

  /// Creates an HTTP response from a cached result
  http.Response _createResponseFromCachedResult(CachedResult result) {
    final headers = _service.createCachedResponseHeaders(
      result.entry,
      result.age,
      result.isStale,
      warning: result.warning,
    );

    return http.Response.bytes(
      result.entry.body,
      result.entry.statusCode,
      headers: headers,
    );
  }

  /// Creates an HTTP response from a cached entry
  http.Response _createResponseFromCache(
    CacheEntry entry,
    int age,
    bool isStale, {
    String? warning,
  }) {
    final headers = _service.createCachedResponseHeaders(
      entry,
      age,
      isStale,
      warning: warning,
    );

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
