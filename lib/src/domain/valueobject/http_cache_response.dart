import 'package:http/http.dart' as http;

/// Represents an HTTP response for caching purposes
/// Simplifies the Core Cache API by encapsulating response data
class HttpCacheResponse {
  final int statusCode;
  final Map<String, String> headers;
  final List<int> body;
  final DateTime requestTime;
  final DateTime responseTime;
  final String? reasonPhrase;

  const HttpCacheResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.requestTime,
    required this.responseTime,
    this.reasonPhrase,
  });

  /// Creates a cache response from an http.Response with timing info
  factory HttpCacheResponse.fromHttpResponse(
    http.Response response, {
    required DateTime requestTime,
    required DateTime responseTime,
  }) {
    return HttpCacheResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.bodyBytes,
      requestTime: requestTime,
      responseTime: responseTime,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Creates a cache response from a streamed response with timing info
  static Future<HttpCacheResponse> fromStreamedResponse(
    http.StreamedResponse response, {
    required DateTime requestTime,
    required DateTime responseTime,
  }) async {
    final body = await response.stream.toBytes();
    return HttpCacheResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: body,
      requestTime: requestTime,
      responseTime: responseTime,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Network latency in milliseconds
  int get latencyMs => responseTime.difference(requestTime).inMilliseconds;

  /// Response size in bytes
  int get sizeBytes => body.length;

  /// Response body as string
  String get bodyString => String.fromCharCodes(body);

  HttpCacheResponse copyWith({
    int? statusCode,
    Map<String, String>? headers,
    List<int>? body,
    DateTime? requestTime,
    DateTime? responseTime,
    String? reasonPhrase,
  }) {
    return HttpCacheResponse(
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      requestTime: requestTime ?? this.requestTime,
      responseTime: responseTime ?? this.responseTime,
      reasonPhrase: reasonPhrase ?? this.reasonPhrase,
    );
  }

  @override
  String toString() {
    return 'HttpCacheResponse{statusCode: $statusCode, size: ${sizeBytes}B, latency: ${latencyMs}ms}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HttpCacheResponse &&
          runtimeType == other.runtimeType &&
          statusCode == other.statusCode &&
          _mapEquals(headers, other.headers) &&
          _listEquals(body, other.body) &&
          requestTime == other.requestTime &&
          responseTime == other.responseTime &&
          reasonPhrase == other.reasonPhrase;

  @override
  int get hashCode =>
      statusCode.hashCode ^
      _mapHashCode(headers) ^
      _listHashCode(body) ^
      requestTime.hashCode ^
      responseTime.hashCode ^
      reasonPhrase.hashCode;

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

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int _listHashCode(List<int> list) {
    return list.fold(0, (hash, element) => hash ^ element.hashCode);
  }
}
