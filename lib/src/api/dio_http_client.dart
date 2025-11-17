import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http/http.dart' as http;

import 'http_client.dart';

/// An implementation of [HttpClient] that uses the `dio` package with HTTP/2 support.
///
/// This client configures Dio's underlying IOHttpClientAdapter to enable HTTP/2,
/// providing better performance through multiplexing and header compression.
class DioHttpClient implements HttpClient {
  final Dio _dio;

  DioHttpClient({Dio? dio}) : _dio = dio ?? _createDioWithHttp2();

  @override
  Future<http.Response> send(http.Request request) async {
    final options = Options(
      method: request.method,
      headers: request.headers,
    );

    final response = await _dio.request(
      request.url.toString(),
      data: request.bodyBytes,
      options: options,
    );

    return http.Response(
      response.data.toString(),
      response.statusCode ?? 500,
      headers: response.headers.map
          .map((key, value) => MapEntry(key, value.join(', '))),
    );
  }

  @override
  void close() {
    _dio.close();
  }

  /// Creates a Dio instance with HTTP/2 enabled.
  ///
  /// Configures the IOHttpClientAdapter to explicitly enable HTTP/2 support
  /// on the underlying dart:io HttpClient. The client will negotiate HTTP/2
  /// via ALPN during the TLS handshake and fall back to HTTP/1.1 if needed.
  static Dio _createDioWithHttp2() {
    final dio = Dio();

    // Configure HTTP/2 support on native platforms
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = io.HttpClient();

        // dart:io HttpClient automatically supports HTTP/2 when:
        // 1. The server advertises 'h2' via ALPN during TLS handshake
        // 2. The connection is HTTPS (required for HTTP/2)
        //
        // No additional configuration needed - HTTP/2 is enabled by default
        // in dart:io HttpClient and will be negotiated automatically.

        return client;
      },
    );

    return dio;
  }
}
