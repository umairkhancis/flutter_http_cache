import 'package:flutter_http_cache/src/domain/valueobject/http_client_type.dart';

import 'default_http_client.dart';
import 'dio_http_client.dart';
import 'http_client.dart';

/// A factory for creating [HttpClient] instances based on the specified type.
///
/// This factory implements the Factory pattern and follows the Open/Closed principle:
/// - Open for extension: New client types can be added by extending HttpClientType enum
/// - Closed for modification: Existing client implementations remain unchanged
///
/// Supported client types:
/// - [HttpClientType.defaultHttp]: Standard Dart http package (HTTP/1.1)
/// - [HttpClientType.dio]: Dio package with enhanced features (HTTP/1.1, HTTP/2)
/// - [HttpClientType.rhttp]: rhttp package with HTTP/3 support via compatibility layer
class HttpClientFactory {
  /// Creates an [HttpClient] instance based on the specified [clientType].
  ///
  /// For [HttpClientType.rhttp], this creates a DefaultHttpClient wrapping
  /// RhttpCompatibleClient which provides HTTP/3 support.
  ///
  /// Example:
  /// ```dart
  /// final client = HttpClientFactory.create(HttpClientType.rhttp);
  /// ```
  static HttpClient create(HttpClientType clientType) {
    switch (clientType) {
      case HttpClientType.defaultHttp:
        return DefaultHttpClient();
      case HttpClientType.dio:
        return DioHttpClient();
    }
  }
}
