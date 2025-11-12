import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_http_cache/src/domain/service/header_utils.dart';

/// Generates cache keys according to HTTP caching: and 4.1
class CacheKeyGenerator {
  /// Generates a primary cache key from HTTP method and target URI
  /// HTTP caching: The primary cache key consists of the request method and target URI
  static String generatePrimaryKey(String method, Uri uri) {
    // Normalize the URI (remove fragment)
    final normalizedUri = uri.removeFragment();

    // Create key from method + normalized URI
    final keyString = '${method.toUpperCase()}:${normalizedUri.toString()}';

    // Hash for consistent key length
    final bytes = utf8.encode(keyString);
    final hash = sha256.convert(bytes);

    return hash.toString();
  }

  /// Generates a complete cache key incorporating Vary header fields
  /// HTTP caching: Vary header field nominates request header fields
  /// that must be matched for cache reuse
  static String generateVaryKey(
    String method,
    Uri uri,
    Map<String, String> requestHeaders,
    String? varyHeaderValue,
    {String? referringSite}
  ) {
    final primaryKey = generatePrimaryKey(method, uri);

    // If no Vary header, return primary key only
    if (varyHeaderValue == null || varyHeaderValue.isEmpty) {
      // Apply double-keying if referringSite provided (for privacy)
      if (referringSite != null) {
        return _addDoubleKey(primaryKey, referringSite);
      }
      return primaryKey;
    }

    // HTTP caching standard: Vary: * means response cannot be matched
    // We still generate a key but mark it as unmatchable
    if (varyHeaderValue.trim() == '*') {
      return '$primaryKey:vary-star';
    }

    // Parse Vary header field names
    final varyFields = _parseVaryFields(varyHeaderValue);

    // Normalize and extract the nominated header fields from request
    final varyValues = <String, String>{};
    for (final fieldName in varyFields) {
      final value = HeaderUtils.getHeader(requestHeaders, fieldName);
      if (value != null) {
        // Normalize the header value (whitespace, case)
        varyValues[fieldName.toLowerCase()] = HeaderUtils.normalizeHeaderValue(value);
      } else {
        // Header not present in request
        varyValues[fieldName.toLowerCase()] = '';
      }
    }

    // Sort keys for consistent hashing
    final sortedKeys = varyValues.keys.toList()..sort();
    final varyString = sortedKeys.map((k) => '$k:${varyValues[k]}').join('|');

    // Combine primary key with vary fields
    final fullKey = '$primaryKey:vary:$varyString';

    // Apply double-keying if referringSite provided
    if (referringSite != null) {
      return _addDoubleKey(fullKey, referringSite);
    }

    // Hash the combined key
    final bytes = utf8.encode(fullKey);
    final hash = sha256.convert(bytes);

    return hash.toString();
  }

  /// Parses Vary header field names
  static List<String> _parseVaryFields(String varyHeaderValue) {
    return varyHeaderValue
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty && f != '*')
        .toList();
  }

  /// Adds double-keying for privacy (timing attack mitigation)
  /// HTTP caching: Include referring site identity in cache key
  static String _addDoubleKey(String key, String referringSite) {
    final bytes = utf8.encode('$key:site:$referringSite');
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Checks if two sets of request headers match for Vary purposes
  /// HTTP caching: Selecting header fields for cache key
  static bool matchesVary(
    String? varyHeaderValue,
    Map<String, String> requestHeaders1,
    Map<String, String> requestHeaders2,
  ) {
    // No Vary header means automatic match
    if (varyHeaderValue == null || varyHeaderValue.isEmpty) {
      return true;
    }

    // Vary: * means no match ever
    if (varyHeaderValue.trim() == '*') {
      return false;
    }

    // Parse and compare nominated fields
    final varyFields = _parseVaryFields(varyHeaderValue);

    for (final fieldName in varyFields) {
      final value1 = HeaderUtils.getHeader(requestHeaders1, fieldName);
      final value2 = HeaderUtils.getHeader(requestHeaders2, fieldName);

      // Normalize values for comparison
      final normalized1 = value1 != null ? HeaderUtils.normalizeHeaderValue(value1) : '';
      final normalized2 = value2 != null ? HeaderUtils.normalizeHeaderValue(value2) : '';

      if (normalized1 != normalized2) {
        return false;
      }
    }

    return true;
  }

  /// Extracts Vary-nominated headers from request for storage
  static Map<String, String>? extractVaryHeaders(
    String? varyHeaderValue,
    Map<String, String> requestHeaders,
  ) {
    if (varyHeaderValue == null || varyHeaderValue.isEmpty) {
      return null;
    }

    if (varyHeaderValue.trim() == '*') {
      return {'*': '*'};
    }

    final varyFields = _parseVaryFields(varyHeaderValue);
    final varyHeaders = <String, String>{};

    for (final fieldName in varyFields) {
      final value = HeaderUtils.getHeader(requestHeaders, fieldName);
      if (value != null) {
        varyHeaders[fieldName.toLowerCase()] = value;
      }
    }

    return varyHeaders.isEmpty ? null : varyHeaders;
  }
}
