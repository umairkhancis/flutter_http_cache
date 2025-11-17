import 'package:meta/meta.dart';

/// Represents a cached HTTP response with metadata
/// Implements HTTP caching: - Storing Responses in Caches
@immutable
class CacheEntry {
  /// The HTTP method used for the request
  final String method;

  /// The target URI of the request
  final Uri uri;

  /// The HTTP status code of the response
  final int statusCode;

  /// The response headers (excluding prohibited headers)
  /// Prohibited: Connection, Proxy-Authentication-Info, Proxy-Authorization, Proxy-Authenticate
  final Map<String, String> headers;

  /// The response body as bytes
  final List<int> body;

  /// Time when the response was received by the cache
  final DateTime responseTime;

  /// Time when the request was initiated
  final DateTime requestTime;

  /// Vary header fields from the original request
  /// Used for cache key matching
  final Map<String, String>? varyHeaders;

  /// Whether this is an incomplete response
  final bool isIncomplete;

  /// Content-Range header value for partial responses
  final String? contentRange;

  /// Whether this entry has been marked as invalid
  final bool isInvalid;

  const CacheEntry({
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.responseTime,
    required this.requestTime,
    this.varyHeaders,
    this.isIncomplete = false,
    this.contentRange,
    this.isInvalid = false,
  });

  /// Creates a CacheEntry from a stored representation
  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    return CacheEntry(
      method: map['method'] as String,
      uri: Uri.parse(map['uri'] as String),
      statusCode: map['statusCode'] as int,
      headers: Map<String, String>.from(map['headers'] as Map),
      body: (map['body'] as List).cast<int>(),
      responseTime: DateTime.parse(map['responseTime'] as String),
      requestTime: DateTime.parse(map['requestTime'] as String),
      varyHeaders: map['varyHeaders'] != null
          ? Map<String, String>.from(map['varyHeaders'] as Map)
          : null,
      isIncomplete: map['isIncomplete'] as bool? ?? false,
      contentRange: map['contentRange'] as String?,
      isInvalid: map['isInvalid'] as bool? ?? false,
    );
  }

  /// Converts the CacheEntry to a storable map
  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'uri': uri.toString(),
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'responseTime': responseTime.toIso8601String(),
      'requestTime': requestTime.toIso8601String(),
      'varyHeaders': varyHeaders,
      'isIncomplete': isIncomplete,
      'contentRange': contentRange,
      'isInvalid': isInvalid,
    };
  }

  /// Creates a copy with updated fields
  CacheEntry copyWith({
    String? method,
    Uri? uri,
    int? statusCode,
    Map<String, String>? headers,
    List<int>? body,
    DateTime? responseTime,
    DateTime? requestTime,
    Map<String, String>? varyHeaders,
    bool? isIncomplete,
    String? contentRange,
    bool? isInvalid,
  }) {
    return CacheEntry(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      responseTime: responseTime ?? this.responseTime,
      requestTime: requestTime ?? this.requestTime,
      varyHeaders: varyHeaders ?? this.varyHeaders,
      isIncomplete: isIncomplete ?? this.isIncomplete,
      contentRange: contentRange ?? this.contentRange,
      isInvalid: isInvalid ?? this.isInvalid,
    );
  }

  /// Gets a header value (case-insensitive)
  String? getHeader(String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Gets the Date header value
  DateTime? get dateHeader {
    final dateStr = getHeader('date');
    if (dateStr == null) return null;
    try {
      return HttpDate.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Gets the Age header value in seconds
  int? get ageHeader {
    final ageStr = getHeader('age');
    if (ageStr == null) return null;
    return int.tryParse(ageStr);
  }

  /// Gets the Expires header value
  DateTime? get expiresHeader {
    final expiresStr = getHeader('expires');
    if (expiresStr == null) return null;
    try {
      return HttpDate.parse(expiresStr);
    } catch (_) {
      // HTTP caching standard: Invalid Expires should be treated as expired
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Gets the Last-Modified header value
  DateTime? get lastModifiedHeader {
    final lmStr = getHeader('last-modified');
    if (lmStr == null) return null;
    try {
      return HttpDate.parse(lmStr);
    } catch (_) {
      return null;
    }
  }

  /// Gets the ETag header value
  String? get eTag {
    return getHeader('etag');
  }

  /// Checks if the ETag is a strong validator (HTTP semantics standard)
  bool get hasStrongETag {
    final tag = eTag;
    if (tag == null) return false;
    return !tag.startsWith('W/');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CacheEntry &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          uri == other.uri &&
          statusCode == other.statusCode &&
          responseTime == other.responseTime &&
          requestTime == other.requestTime;

  @override
  int get hashCode =>
      method.hashCode ^
      uri.hashCode ^
      statusCode.hashCode ^
      responseTime.hashCode ^
      requestTime.hashCode;
}

/// Utility class for parsing HTTP dates
class HttpDate {
  /// Parses an HTTP date string
  static DateTime parse(String dateStr) {
    try {
      return DateTime.parse(dateStr.trim());
    } catch (_) {
      rethrow;
    }
  }

  /// Formats a DateTime as an HTTP date string
  static String format(DateTime date) {
    return date.toUtc().toIso8601String();
  }
}
