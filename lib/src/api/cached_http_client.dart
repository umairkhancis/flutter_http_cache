import 'package:flutter_http_cache/src/api/cache.dart';
import 'package:flutter_http_cache/src/api/http_cache_interceptor.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_policy.dart';
import 'package:http/http.dart' as http;

/// HTTP client with built-in caching
class CachedHttpClient extends http.BaseClient {
  final HttpCacheInterceptor _interceptor;
  CachePolicy? defaultCachePolicy;

  CachedHttpClient({
    required HttpCache cache,
    http.Client? innerClient,
    this.defaultCachePolicy,
  }) : _interceptor = HttpCacheInterceptor(
          cache: cache,
          innerClient: innerClient,
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

    // For non-Request types, pass through
    return _interceptor.innerClient.send(request);
  }

  @override
  void close() {
    _interceptor.close();
    super.close();
  }
}
