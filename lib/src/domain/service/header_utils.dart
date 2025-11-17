/// Utilities for HTTP header manipulation and normalization
class HeaderUtils {
  /// Prohibited headers that must not be stored in cache
  static const List<String> prohibitedHeaders = [
    'connection',
    'proxy-authentication-info',
    'proxy-authorization',
    'proxy-authenticate',
  ];

  /// Gets a header value (case-insensitive lookup)
  static String? getHeader(Map<String, String> headers, String name) {
    final lowerName = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Normalizes a header value for comparison
  /// HTTP caching: Normalize whitespace and handle case sensitivity
  static String normalizeHeaderValue(String value) {
    // Trim leading/trailing whitespace
    var normalized = value.trim();

    // Collapse multiple whitespace into single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  /// Filters out prohibited headers from a header map
  /// HTTP caching: These headers must not be stored
  static Map<String, String> filterProhibitedHeaders(Map<String, String> headers) {
    final filtered = <String, String>{};

    for (final entry in headers.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (!prohibitedHeaders.contains(lowerKey)) {
        filtered[entry.key] = entry.value;
      }
    }

    return filtered;
  }

  /// Checks if a header field name is prohibited from storage
  static bool isProhibitedHeader(String name) {
    return prohibitedHeaders.contains(name.toLowerCase());
  }

  /// Merges two header maps (case-insensitive, later values override earlier)
  static Map<String, String> mergeHeaders(
    Map<String, String> base,
    Map<String, String> overrides,
  ) {
    final merged = Map<String, String>.from(base);

    for (final entry in overrides.entries) {
      // Find if key already exists (case-insensitive)
      String? existingKey;
      for (final key in merged.keys) {
        if (key.toLowerCase() == entry.key.toLowerCase()) {
          existingKey = key;
          break;
        }
      }

      // Remove old key if exists, add new one
      if (existingKey != null) {
        merged.remove(existingKey);
      }
      merged[entry.key] = entry.value;
    }

    return merged;
  }

  /// Updates stored response headers from a 304 Not Modified response
  /// HTTP caching: Updating stored header fields
  static Map<String, String> updateHeadersFrom304(
    Map<String, String> storedHeaders,
    Map<String, String> validationResponseHeaders,
  ) {
    final updated = Map<String, String>.from(storedHeaders);

    // Headers that should be updated from 304 response
    final updateableHeaders = [
      'cache-control',
      'date',
      'etag',
      'expires',
      'vary',
      'warning',
    ];

    for (final headerName in updateableHeaders) {
      final newValue = getHeader(validationResponseHeaders, headerName);
      if (newValue != null) {
        // Remove old version (case-insensitive)
        updated.removeWhere((key, _) => key.toLowerCase() == headerName);
        // Add new version
        updated[headerName] = newValue;
      }
    }

    return updated;
  }

  /// Parses a comma-separated list header value
  static List<String> parseListHeader(String? value) {
    if (value == null || value.isEmpty) return [];

    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// Checks if a status code is final (not 1xx)
  /// HTTP semantics standard: Only final responses should be cached
  static bool isFinalStatusCode(int statusCode) {
    return statusCode >= 200;
  }

  /// Checks if a status code is heuristically cacheable
  /// HTTP caching: Status codes that can be cached without explicit directives
  static bool isHeuristicallyCacheable(int statusCode) {
    return const [
      200, // OK
      203, // Non-Authoritative Information
      204, // No Content
      206, // Partial Content
      300, // Multiple Choices
      301, // Moved Permanently
      304, // Not Modified
      404, // Not Found
      405, // Method Not Allowed
      410, // Gone
      414, // URI Too Long
      501, // Not Implemented
    ].contains(statusCode);
  }

  /// Checks if a method is understood by the cache
  /// HTTP caching: Only certain methods should be cached
  static bool isMethodCacheable(String method) {
    final upperMethod = method.toUpperCase();
    return const ['GET', 'HEAD', 'POST'].contains(upperMethod);
  }

  /// Checks if a method allows response reuse for subsequent requests
  /// HTTP caching: GET and HEAD responses can be reused
  static bool isMethodReusable(String method) {
    final upperMethod = method.toUpperCase();
    return const ['GET', 'HEAD'].contains(upperMethod);
  }

  /// Checks if a method is unsafe (invalidates cache)
  /// HTTP caching: PUT, POST, DELETE invalidate cache
  static bool isUnsafeMethod(String method) {
    final upperMethod = method.toUpperCase();
    return const ['PUT', 'POST', 'DELETE', 'PATCH'].contains(upperMethod);
  }

  /// Extracts the warning header value
  static String? getWarningHeader(Map<String, String> headers) {
    return getHeader(headers, 'warning');
  }

  /// Adds a warning header to indicate stale response
  /// HTTP caching: Warning header field
  static Map<String, String> addStaleWarning(
    Map<String, String> headers,
    {String? message}
  ) {
    final updated = Map<String, String>.from(headers);
    final warning = message ?? '110 - "Response is Stale"';

    final existingWarning = getWarningHeader(headers);
    if (existingWarning != null) {
      updated['warning'] = '$existingWarning, $warning';
    } else {
      updated['warning'] = warning;
    }

    return updated;
  }

  /// Removes hop-by-hop headers that shouldn't be cached
  static Map<String, String> removeHopByHopHeaders(Map<String, String> headers) {
    final hopByHop = [
      'connection',
      'keep-alive',
      'proxy-authenticate',
      'proxy-authorization',
      'te',
      'trailer',
      'transfer-encoding',
      'upgrade',
    ];

    final filtered = <String, String>{};
    for (final entry in headers.entries) {
      if (!hopByHop.contains(entry.key.toLowerCase())) {
        filtered[entry.key] = entry.value;
      }
    }

    return filtered;
  }
}
