import 'package:http/http.dart' as http;

/// Abstract class for executing HTTP requests.
/// This allows for interchangeable HTTP client implementations (e.g., http, dio).
abstract class HttpClient {
  Future<http.Response> send(http.Request request);

  void close();
}
