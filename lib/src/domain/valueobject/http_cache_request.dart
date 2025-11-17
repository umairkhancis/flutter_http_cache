import 'package:flutter_http_cache/src/domain/valueobject/cache_policy.dart';
import 'package:http/http.dart' as http;

/// Represents an HTTP request for caching purposes
/// Simplifies the Core Cache API by encapsulating request data
class HttpCacheRequest {
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final CachePolicy? policy;

  const HttpCacheRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.policy,
  });

  /// Creates a cache request from an http.Request
  factory HttpCacheRequest.fromHttpRequest(
    http.Request request, {
    CachePolicy? policy,
  }) {
    return HttpCacheRequest(
      method: request.method,
      uri: request.url,
      headers: request.headers,
      policy: policy,
    );
  }

  /// Creates a simple GET request
  factory HttpCacheRequest.get(
    Uri uri, {
    Map<String, String>? headers,
    CachePolicy? policy,
  }) {
    return HttpCacheRequest(
      method: 'GET',
      uri: uri,
      headers: headers ?? {},
      policy: policy,
    );
  }

  /// Creates a POST request
  factory HttpCacheRequest.post(
    Uri uri, {
    Map<String, String>? headers,
    CachePolicy? policy,
  }) {
    return HttpCacheRequest(
      method: 'POST',
      uri: uri,
      headers: headers ?? {},
      policy: policy,
    );
  }

  HttpCacheRequest copyWith({
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    CachePolicy? policy,
  }) {
    return HttpCacheRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      policy: policy ?? this.policy,
    );
  }

  @override
  String toString() {
    return 'HttpCacheRequest{method: $method, uri: $uri, policy: ${policy?.name}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HttpCacheRequest &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          uri == other.uri &&
          _mapEquals(headers, other.headers) &&
          policy == other.policy;

  @override
  int get hashCode =>
      method.hashCode ^ uri.hashCode ^ _mapHashCode(headers) ^ policy.hashCode;

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  int _mapHashCode(Map<String, String> map) {
    return map.entries.fold(0, (hash, entry) => hash ^ entry.key.hashCode ^ entry.value.hashCode);
  }
}
