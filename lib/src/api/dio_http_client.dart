import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'http_client.dart';

/// An implementation of [HttpClient] that uses the `dio` package.
class DioHttpClient implements HttpClient {
  final Dio _dio;

  DioHttpClient({Dio? dio}) : _dio = dio ?? Dio();

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
      headers: response.headers.map.map((key, value) => MapEntry(key, value.join(', '))),
    );
  }

  @override
  void close() {
    _dio.close();
  }
}
