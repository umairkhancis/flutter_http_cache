import 'default_http_client.dart';
import 'dio_http_client.dart';
import 'http_client.dart';

/// A factory for creating [HttpClient] instances.
class HttpClientFactory {
  static HttpClient create({bool useDio = false}) {
    if (useDio) {
      return DioHttpClient();
    } else {
      return DefaultHttpClient();
    }
  }
}
