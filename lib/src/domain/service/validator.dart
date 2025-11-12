import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';

/// Handles validation and conditional requests
/// Implements HTTP caching: - Validation
class CacheValidator {
  /// Generates conditional request headers for validation
  /// HTTP caching: Sending a Validation Request
  Map<String, String> generateValidationHeaders(
    CacheEntry entry,
    Map<String, String> originalHeaders,
  ) {
    final validationHeaders = Map<String, String>.from(originalHeaders);

    // Add If-None-Match if ETag is present (preferred)
    final eTag = entry.eTag;
    if (eTag != null) {
      validationHeaders['if-none-match'] = eTag;
    }

    // Add If-Modified-Since if Last-Modified is present
    final lastModified = entry.lastModifiedHeader;
    if (lastModified != null) {
      validationHeaders['if-modified-since'] =
          lastModified.toUtc().toIso8601String();
    }

    return validationHeaders;
  }

  /// Checks if a 304 Not Modified response matches the cached entry
  /// HTTP caching: Handling a Received Validation Request
  bool matches304Response(
    CacheEntry cachedEntry,
    Map<String, String> response304Headers,
  ) {
    // Check ETag match (strong validator)
    final responseETag = HeaderUtils.getHeader(response304Headers, 'etag');
    if (responseETag != null && cachedEntry.eTag != null) {
      return _matchStrongValidator(cachedEntry.eTag!, responseETag);
    }

    // Check Last-Modified match (weak validator)
    final responseLastModified =
        HeaderUtils.getHeader(response304Headers, 'last-modified');
    if (responseLastModified != null &&
        cachedEntry.lastModifiedHeader != null) {
      return _matchWeakValidator(
        cachedEntry.lastModifiedHeader!.toIso8601String(),
        responseLastModified,
      );
    }

    // If no validators present, assume match
    return true;
  }

  /// Updates cached entry from a 304 Not Modified response
  /// HTTP caching: Updating Stored Header Fields
  CacheEntry updateFrom304(
    CacheEntry cachedEntry,
    Map<String, String> response304Headers,
    DateTime validationResponseTime,
    DateTime validationRequestTime,
  ) {
    // Update headers from 304 response
    final updatedHeaders = HeaderUtils.updateHeadersFrom304(
      cachedEntry.headers,
      response304Headers,
    );

    // Create updated entry with new response times
    return cachedEntry.copyWith(
      headers: updatedHeaders,
      responseTime: validationResponseTime,
      requestTime: validationRequestTime,
    );
  }

  /// Checks if a HEAD response can freshen a cached GET response
  /// HTTP caching: Freshening Stored Responses with HEAD
  bool canFreshenWithHEAD(
    CacheEntry cachedGetEntry,
    CacheEntry headEntry,
  ) {
    // Must match validators
    if (!_matchesValidators(cachedGetEntry, headEntry)) {
      return false;
    }

    // Must match Content-Length if present
    final cachedLength =
        HeaderUtils.getHeader(cachedGetEntry.headers, 'content-length');
    final headLength = HeaderUtils.getHeader(headEntry.headers, 'content-length');

    if (cachedLength != null && headLength != null) {
      if (cachedLength != headLength) {
        return false;
      }
    }

    return true;
  }

  /// Updates cached GET entry from HEAD response
  CacheEntry updateFromHEAD(
    CacheEntry cachedGetEntry,
    CacheEntry headEntry,
  ) {
    // Update headers from HEAD response
    final updatedHeaders = HeaderUtils.mergeHeaders(
      cachedGetEntry.headers,
      headEntry.headers,
    );

    // Create updated entry preserving GET method and body
    return cachedGetEntry.copyWith(
      headers: updatedHeaders,
      responseTime: headEntry.responseTime,
      requestTime: headEntry.requestTime,
    );
  }

  /// Matches strong validators (ETag)
  /// HTTP semantics standard: Strong comparison requires exact match
  bool _matchStrongValidator(String validator1, String validator2) {
    return validator1 == validator2;
  }

  /// Matches weak validators (Last-Modified, or weak ETags)
  /// HTTP semantics standard: Weak comparison allows W/ prefix
  bool _matchWeakValidator(String validator1, String validator2) {
    // Remove W/ prefix for comparison
    final v1 = validator1.startsWith('W/') ? validator1.substring(2) : validator1;
    final v2 = validator2.startsWith('W/') ? validator2.substring(2) : validator2;

    return v1 == v2;
  }

  /// Checks if two entries have matching validators
  bool _matchesValidators(CacheEntry entry1, CacheEntry entry2) {
    // Check ETag
    if (entry1.eTag != null && entry2.eTag != null) {
      // For HEAD freshening, weak match is sufficient
      if (_matchWeakValidator(entry1.eTag!, entry2.eTag!)) {
        return true;
      }
    }

    // Check Last-Modified
    if (entry1.lastModifiedHeader != null && entry2.lastModifiedHeader != null) {
      if (entry1.lastModifiedHeader == entry2.lastModifiedHeader) {
        return true;
      }
    }

    return false;
  }

  /// Determines if a validator is strong or weak
  bool isStrongValidator(String? eTag) {
    if (eTag == null) return false;
    return !eTag.startsWith('W/');
  }

  /// Determines if a cached entry has usable validators
  bool hasValidators(CacheEntry entry) {
    return entry.eTag != null || entry.lastModifiedHeader != null;
  }

  /// Generates If-Range header for partial content requests
  String? generateIfRangeHeader(CacheEntry entry) {
    // Prefer ETag if it's a strong validator
    if (entry.hasStrongETag) {
      return entry.eTag;
    }

    // Fallback to Last-Modified
    if (entry.lastModifiedHeader != null) {
      return entry.lastModifiedHeader!.toUtc().toIso8601String();
    }

    return null;
  }
}
