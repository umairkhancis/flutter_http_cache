import 'package:http/http.dart' as http;
import 'http_client.dart';

/// An implementation of [HttpClient] that uses the `http` package.
class DefaultHttpClient implements HttpClient {
  final http.Client _client;

  DefaultHttpClient({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<http.Response> send(http.Request request) async {
    final response = await _client.send(request);
    return http.Response.fromStream(response);
  }

  @override
  void close() {
    _client.close();
  }
}
