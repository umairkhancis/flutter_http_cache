import 'package:flutter_http_cache/src/domain/service/header_utils.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_control.dart';

/// Calculates heuristic freshness when no explicit expiration is provided
/// Implements HTTP caching heuristic freshness calculation
class HeuristicFreshnessCalculator {
  /// Whether heuristic freshness is enabled
  final bool enabled;

  /// The percentage of time since Last-Modified to use as freshness
  /// HTTP caching standard recommends 10%
  final double percentage;

  /// Maximum heuristic freshness lifetime
  /// Prevents excessively long heuristic freshness periods
  final Duration maxDuration;

  const HeuristicFreshnessCalculator({
    this.enabled = true,
    this.percentage = 0.10, // 10% as recommended by HTTP caching standard
    this.maxDuration = const Duration(days: 7),
  });

  /// Calculates heuristic freshness for a response
  /// HTTP caching heuristic freshness:
  /// - Only apply when no explicit expiration exists
  /// - Use Last-Modified if available (recommend 10% of time since modification)
  /// - Only for "heuristically cacheable" status codes or responses with public directive
  Duration? calculateHeuristicFreshness(
    CacheEntry entry,
    CacheControl cacheControl,
  ) {
    if (!enabled) {
      return null;
    }

    // Only apply heuristic freshness if appropriate
    if (!_canUseHeuristicFreshness(entry, cacheControl)) {
      return null;
    }

    // If Last-Modified is present, use it for calculation
    final lastModified = entry.lastModifiedHeader;
    if (lastModified != null) {
      final dateValue = entry.dateHeader ?? entry.responseTime;

      // Time since last modification
      final timeSinceModification = dateValue.difference(lastModified);

      if (timeSinceModification.isNegative) {
        // Last-Modified is in the future, invalid
        return null;
      }

      // Calculate heuristic freshness as percentage of time since modification
      final heuristicFreshness = Duration(
        milliseconds: (timeSinceModification.inMilliseconds * percentage).round(),
      );

      // Cap at maximum duration
      return heuristicFreshness > maxDuration ? maxDuration : heuristicFreshness;
    }

    // No Last-Modified header, use a conservative default
    // Only if status code is heuristically cacheable
    if (HeaderUtils.isHeuristicallyCacheable(entry.statusCode)) {
      return const Duration(minutes: 5); // Conservative default
    }

    return null;
  }

  /// Checks if heuristic freshness can be applied to this response
  bool _canUseHeuristicFreshness(
    CacheEntry entry,
    CacheControl cacheControl,
  ) {
    // Heuristic freshness is only for responses without explicit expiration
    // (Checked by caller - they only call this if no max-age/Expires)

    // If response has public directive, heuristic caching is allowed
    if (cacheControl.isPublic) {
      return true;
    }

    // If response has no-cache or no-store, don't use heuristic
    if (cacheControl.noCache || cacheControl.noStore) {
      return false;
    }

    // Check if status code is heuristically cacheable
    return HeaderUtils.isHeuristicallyCacheable(entry.statusCode);
  }

  /// Gets a warning message for responses using heuristic freshness
  /// Warning 113 - Heuristic Expiration
  String getHeuristicWarning(Duration heuristicFreshness) {
    return '113 - "Heuristic Expiration: ${heuristicFreshness.inSeconds}s"';
  }

  /// Checks if a response is using heuristic freshness
  bool isUsingHeuristicFreshness(
    CacheEntry entry,
    CacheControl cacheControl,
  ) {
    // Has explicit expiration?
    if (cacheControl.maxAge != null ||
        cacheControl.sMaxAge != null ||
        entry.expiresHeader != null) {
      return false;
    }

    // Can use heuristic freshness?
    return _canUseHeuristicFreshness(entry, cacheControl);
  }
}
