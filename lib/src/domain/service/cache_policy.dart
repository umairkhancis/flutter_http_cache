import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_control.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_type.dart';

/// Determines caching policies for requests and responses
/// Implements HTTP caching: - Storing Responses in Caches
class CachePolicyDecisions {
  final CacheType cacheType;

  const CachePolicyDecisions({
    this.cacheType = CacheType.private,
  });

  /// Determines if a response can be stored in the cache
  /// HTTP caching: Storing Responses in Caches
  ///
  /// A cache MUST NOT store a response if:
  /// - The request method is not understood by the cache
  /// - The response status code is not final
  /// - The no-store directive is present
  /// - The private directive is present (for shared caches)
  /// - Authorization header requirements not met
  ///
  /// A response is storable if at least one of these is true:
  /// - public directive present
  /// - private directive present (private caches only)
  /// - Expires header present
  /// - max-age directive present
  /// - s-maxage directive present (shared caches)
  /// - Cache extension allowing storage
  /// - Heuristically cacheable status code
  CacheStorability canStore({
    required String method,
    required int statusCode,
    required Map<String, String> requestHeaders,
    required Map<String, String> responseHeaders,
    required CacheControl requestCacheControl,
    required CacheControl responseCacheControl,
  }) {
    // Check 1: Method must be understood by cache
    if (!HeaderUtils.isMethodCacheable(method)) {
      return CacheStorability.notStorable(
        'Request method $method is not cacheable',
      );
    }

    // Check 2: Status code must be final (not 1xx)
    if (!HeaderUtils.isFinalStatusCode(statusCode)) {
      return CacheStorability.notStorable(
        'Status code $statusCode is not final',
      );
    }

    // Check 3: Handle special status codes with must-understand
    if ((statusCode == 206 || statusCode == 304) &&
        responseCacheControl.mustUnderstand) {
      // Only cache if the cache understands the status code
      // For this implementation, we understand 206 and 304
      // Continue checking other conditions
    }

    // Check 4: no-store directive prohibits storage
    if (responseCacheControl.noStore || requestCacheControl.requestNoStore) {
      return CacheStorability.notStorable(
        'no-store directive present',
      );
    }

    // Check 5: private directive for shared caches
    if (cacheType == CacheType.shared && responseCacheControl.isPrivate) {
      return CacheStorability.notStorable(
        'private directive present for shared cache',
      );
    }

    // Check 6: Authorization header requirements
    final hasAuthorization = HeaderUtils.getHeader(requestHeaders, 'authorization') != null;
    if (hasAuthorization) {
      if (!_authorizationAllowsStorage(responseCacheControl)) {
        return CacheStorability.notStorable(
          'Authorization header present without explicit caching directive',
        );
      }
    }

    // Check 7: At least one cacheable indicator must exist
    if (!_hasStorageIndicator(statusCode, responseCacheControl, responseHeaders)) {
      return CacheStorability.notStorable(
        'No explicit caching directive or heuristically cacheable status code',
      );
    }

    return CacheStorability.storable();
  }

  /// Checks if Authorization header allows caching
  /// HTTP caching: Responses to requests with Authorization can only be
  /// stored if explicitly allowed by response directives
  bool _authorizationAllowsStorage(CacheControl responseCacheControl) {
    return responseCacheControl.isPublic ||
        responseCacheControl.mustRevalidate ||
        responseCacheControl.sMaxAge != null;
  }

  /// Checks if response has at least one storage indicator
  bool _hasStorageIndicator(
    int statusCode,
    CacheControl cacheControl,
    Map<String, String> responseHeaders,
  ) {
    // public directive
    if (cacheControl.isPublic) return true;

    // private directive (for private caches)
    if (cacheType == CacheType.private && cacheControl.isPrivate) return true;

    // Expires header
    if (HeaderUtils.getHeader(responseHeaders, 'expires') != null) return true;

    // max-age directive
    if (cacheControl.maxAge != null) return true;

    // s-maxage directive (for shared caches)
    if (cacheType == CacheType.shared && cacheControl.sMaxAge != null) return true;

    // Heuristically cacheable status code
    if (HeaderUtils.isHeuristicallyCacheable(statusCode)) return true;

    return false;
  }

  /// Determines if a stored response can be reused for a request
  /// HTTP caching: Constructing Responses from Caches
  CacheReusability canReuse({
    required CacheEntry entry,
    required String requestMethod,
    required Uri requestUri,
    required Map<String, String> requestHeaders,
    required CacheControl requestCacheControl,
    required CacheControl responseCacheControl,
    required bool isFresh,
    String? varyHeaderValue,
  }) {
    // Check 1: Entry must not be marked as invalid
    if (entry.isInvalid) {
      return CacheReusability.notReusable('Entry marked as invalid');
    }

    // Check 2: Request method must allow reuse
    if (!HeaderUtils.isMethodReusable(requestMethod)) {
      return CacheReusability.notReusable(
        'Request method $requestMethod does not allow response reuse',
      );
    }

    // Check 3: Target URI must match exactly
    if (entry.uri != requestUri) {
      return CacheReusability.notReusable('URI mismatch');
    }

    // Check 4: Vary header must match
    if (varyHeaderValue != null) {
      if (varyHeaderValue.trim() == '*') {
        return CacheReusability.notReusable('Vary: * cannot be matched');
      }

      if (entry.varyHeaders != null) {
        final varyFields = varyHeaderValue.split(',').map((f) => f.trim());
        for (final fieldName in varyFields) {
          final storedValue = entry.varyHeaders![fieldName.toLowerCase()];
          final requestValue = HeaderUtils.getHeader(requestHeaders, fieldName) ?? '';

          if (storedValue != requestValue) {
            return CacheReusability.notReusable('Vary header field $fieldName mismatch');
          }
        }
      }
    }

    // Check 5: Handle no-cache directive
    if (responseCacheControl.noCache || requestCacheControl.requestNoCache) {
      return CacheReusability.requiresValidation('no-cache directive present');
    }

    // Check 6: Verify response is fresh, stale-allowed, or will be validated
    if (!isFresh) {
      return CacheReusability.requiresValidation('Response is stale');
    }

    return CacheReusability.reusable();
  }
}

/// Result of storage policy decision
class CacheStorability {
  final bool storable;
  final String? reason;

  const CacheStorability._(this.storable, this.reason);

  factory CacheStorability.storable() => const CacheStorability._(true, null);

  factory CacheStorability.notStorable(String reason) =>
      CacheStorability._(false, reason);

  @override
  String toString() => storable ? 'Storable' : 'Not Storable: $reason';
}

/// Result of reuse policy decision
class CacheReusability {
  final ReusabilityType type;
  final String? reason;

  const CacheReusability._(this.type, this.reason);

  factory CacheReusability.reusable() =>
      const CacheReusability._(ReusabilityType.reusable, null);

  factory CacheReusability.notReusable(String reason) =>
      CacheReusability._(ReusabilityType.notReusable, reason);

  factory CacheReusability.requiresValidation(String reason) =>
      CacheReusability._(ReusabilityType.requiresValidation, reason);

  bool get isReusable => type == ReusabilityType.reusable;
  bool get needsValidation => type == ReusabilityType.requiresValidation;

  @override
  String toString() {
    switch (type) {
      case ReusabilityType.reusable:
        return 'Reusable';
      case ReusabilityType.notReusable:
        return 'Not Reusable: $reason';
      case ReusabilityType.requiresValidation:
        return 'Requires Validation: $reason';
    }
  }
}

enum ReusabilityType {
  reusable,
  notReusable,
  requiresValidation,
}
