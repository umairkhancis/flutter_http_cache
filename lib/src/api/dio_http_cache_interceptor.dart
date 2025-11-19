import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:flutter_http_cache/src/domain/service/cache_interceptor_service.dart';

/// Dio interceptor for HTTP caching
///
/// This interceptor provides transparent HTTP caching for Dio by delegating
/// all caching logic to [CacheInterceptorService]. It acts as a thin adapter
/// between Dio's interceptor model and the core caching logic.
///
/// This follows the Dependency Inversion Principle by depending on the
/// abstract [CacheInterceptorService] rather than implementing caching logic directly.
///
/// Example:
/// ```dart
/// final cache = HttpCache(config: CacheConfig());
/// await cache.initialize();
///
/// final dio = Dio();
/// dio.interceptors.add(DioHttpCacheInterceptor(cache));
///
/// // Now all Dio requests will be cached automatically
/// final response = await dio.get('https://api.example.com/data');
/// ```
///
/// The interceptor supports all cache policies and can be configured
/// per-request using the extra options:
/// ```dart
/// final response = await dio.get(
///   'https://api.example.com/data',
///   options: Options(
///     extra: {'cachePolicy': CachePolicy.networkFirst},
///   ),
/// );
/// ```
class DioHttpCacheInterceptor extends Interceptor {
  final HttpCache cache;
  late final CacheInterceptorService _service;

  DioHttpCacheInterceptor(this.cache) {
    _service = CacheInterceptorService(cache);
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await cache.initialize();

    final method = options.method;
    final uri = options.uri;
    final requestHeaders = _extractHeaders(options.headers);

    // Get cache policy from options.extra or use default
    final cachePolicy = options.extra['cachePolicy'] as CachePolicy? ??
        CachePolicy.standard;

    if (cache.config.enableLogging) {
      developer.log(
        'DioHttpCacheInterceptor.onRequest: $method $uri (policy: ${cachePolicy.name})',
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

    switch (result) {
      // Cache hit - return cached response
      case CachedResult():
        final response = _createResponseFromCachedResult(options, result);
        return handler.resolve(response);

      // Continue with network request (possibly with validation)
      case ContinueWithRequest():
        // Add validation headers if provided
        if (result.validationHeaders != null) {
          options.headers.addAll(result.validationHeaders!);
          // Store the cached entry in extra for use in onResponse
          options.extra['_cachedEntry'] = result.cachedEntry;
        }

        // Store request time for later cache storage
        options.extra['_requestTime'] = DateTime.now();

        // Continue with the request
        handler.next(options);

      // Cache miss with cacheOnly policy
      case ErrorResult():
        return handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: result.statusCode,
              statusMessage: result.message,
              headers: Headers.fromMap(
                result.headers.map((k, v) => MapEntry(k, [v])),
              ),
            ),
            type: DioExceptionType.badResponse,
            message: result.message,
          ),
        );
    }
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final requestTime = options.extra['_requestTime'] as DateTime?;
    final responseTime = DateTime.now();
    final method = options.method;
    final uri = options.uri;
    final requestHeaders = _extractHeaders(options.headers);
    final responseHeaders = _extractResponseHeaders(response.headers);

    if (cache.config.enableLogging) {
      developer.log(
        'DioHttpCacheInterceptor.onResponse: Network response received (status: ${response.statusCode})',
        name: 'flutter_http_cache',
      );
    }

    // Get cached entry if this was a validation request
    final cachedEntry = options.extra['_cachedEntry'] as CacheEntry?;

    // Delegate response handling to service
    final result = await _service.handleResponse(
      method: method,
      uri: uri,
      statusCode: response.statusCode!,
      requestHeaders: requestHeaders,
      responseHeaders: responseHeaders,
      body: _extractResponseBody(response),
      requestTime: requestTime ?? DateTime.now(),
      responseTime: responseTime,
      cachedEntry: cachedEntry,
    );

    switch (result) {
      // 304 response - use updated cache
      case UseUpdatedCache():
        if (cache.config.enableLogging) {
          developer.log(
            'DioHttpCacheInterceptor: 304 response - serving updated cached entry',
            name: 'flutter_http_cache',
          );
        }

        final updatedResponse = _createResponseFromCache(
          options,
          result.entry,
          0,
          false,
        );

        return handler.resolve(updatedResponse);

      // Normal response - use network response
      case UseNetworkResponse():
        // Add Age header (0 for fresh responses)
        response.headers.add('age', '0');

        // Continue with the response
        handler.next(response);
    }
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method;
    final uri = options.uri;
    final requestHeaders = _extractHeaders(options.headers);
    final cachePolicy = options.extra['cachePolicy'] as CachePolicy? ??
        CachePolicy.standard;

    if (cache.config.enableLogging) {
      developer.log(
        'DioHttpCacheInterceptor.onError: Network request failed: ${err.message}',
        name: 'flutter_http_cache',
        error: err,
      );
    }

    // Delegate error handling to service
    final errorResult = await _service.handleError(
      method: method,
      uri: uri,
      requestHeaders: requestHeaders,
      cachePolicy: cachePolicy,
    );

    switch (errorResult) {
      // Serve stale cache on error
      case ServeStaleCache():
        if (cache.config.enableLogging) {
          developer.log(
            'DioHttpCacheInterceptor: Serving stale cache on error',
            name: 'flutter_http_cache',
          );
        }

        final response = _createResponseFromCache(
          options,
          errorResult.entry,
          errorResult.age,
          true,
          warning: '111 - "Revalidation Failed"',
        );

        return handler.resolve(response);

      // Propagate error
      case PropagateError():
        // No stale response available - continue with error
        handler.next(err);
    }
  }

  /// Extracts headers from Dio headers map
  Map<String, String> _extractHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (value is List) {
        return MapEntry(key.toLowerCase(), value.join(', '));
      }
      return MapEntry(key.toLowerCase(), value.toString());
    });
  }

  /// Extracts headers from Dio response headers
  Map<String, String> _extractResponseHeaders(Headers headers) {
    final result = <String, String>{};
    headers.forEach((name, values) {
      result[name.toLowerCase()] = values.join(', ');
    });
    return result;
  }

  /// Extracts response body as bytes
  List<int> _extractResponseBody(Response response) {
    final data = response.data;
    if (data is List<int>) {
      return data;
    } else if (data is String) {
      return data.codeUnits;
    } else {
      // For other types, convert to string first
      return data.toString().codeUnits;
    }
  }

  /// Creates a Dio Response from a cached result
  Response _createResponseFromCachedResult(
    RequestOptions options,
    CachedResult result,
  ) {
    final headers = _service.createCachedResponseHeaders(
      result.entry,
      result.age,
      result.isStale,
      warning: result.warning,
    );

    return _buildDioResponse(
      options,
      result.entry.body,
      result.entry.statusCode,
      headers,
    );
  }

  /// Creates a Dio Response from a cached entry
  Response _createResponseFromCache(
    RequestOptions options,
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

    return _buildDioResponse(
      options,
      entry.body,
      entry.statusCode,
      headers,
    );
  }

  /// Builds a Dio Response with proper header format
  Response _buildDioResponse(
    RequestOptions options,
    List<int> body,
    int statusCode,
    Map<String, String> headers,
  ) {
    final dioHeaders = <String, List<String>>{};

    // Convert headers to Dio format
    headers.forEach((key, value) {
      dioHeaders[key] = [value];
    });

    // Decode body to match Dio's normal response transformation
    // This ensures cached responses behave identically to network responses
    dynamic decodedData = body;

    try {
      // Decode bytes to string
      final bodyString = utf8.decode(body);

      // Check if response is JSON and should be parsed
      final contentType = headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        // Parse JSON (matching Dio's default behavior)
        try {
          decodedData = json.decode(bodyString);
        } catch (_) {
          // If JSON parsing fails, use the string
          decodedData = bodyString;
        }
      } else {
        // For non-JSON responses, use the decoded string
        decodedData = bodyString;
      }
    } catch (_) {
      // If decoding fails, fall back to raw bytes
      decodedData = body;
    }

    return Response(
      requestOptions: options,
      data: decodedData,
      statusCode: statusCode,
      headers: Headers.fromMap(dioHeaders),
    );
  }
}
