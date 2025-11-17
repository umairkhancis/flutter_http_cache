import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:http/http.dart' as http;

import 'http_cache_interceptor.dart';

/// HTTP client with built-in caching
class CachedHttpClient extends http.BaseClient {
  final HttpCacheInterceptor _interceptor;
  CachePolicy? defaultCachePolicy;

  CachedHttpClient({
    required HttpCache cache,
    this.defaultCachePolicy,
  }) : _interceptor = HttpCacheInterceptor(
          cache: cache,
        );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      final response = await _interceptor.send(
        request,
        cachePolicy: defaultCachePolicy,
      );

      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        request: request,
      );
    }

    // For non-Request types, pass through to the underlying executor
    // This assumes the underlying executor can handle http.BaseRequest,
    // which is true if it's an http.Client or a Dio adapter that converts it.
    // However, our HttpExecutor interface expects http.Request, so we cast.
    final response =
        await _interceptor.httpExecutor.send(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }

  @override
  void close() {
    _interceptor.close();
    super.close();
  }
}
