import 'package:flutter_http_cache/src/domain/service/age_calculator.dart';
import 'package:flutter_http_cache/src/domain/service/heuristic.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_control.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_type.dart';

/// Determines the freshness of cached responses
/// Implements HTTP caching: - Freshness
class FreshnessCalculator {
  final HeuristicFreshnessCalculator _heuristicCalculator;
  final CacheType _cacheType;

  FreshnessCalculator({
    required HeuristicFreshnessCalculator heuristicCalculator,
    CacheType cacheType = CacheType.private,
  })  : _heuristicCalculator = heuristicCalculator,
        _cacheType = cacheType;

  /// Calculates the freshness lifetime of a cached response
  /// HTTP caching: Calculating Freshness Lifetime
  ///
  /// Priority order:
  /// 1. s-maxage directive (shared caches only)
  /// 2. max-age directive
  /// 3. Expires header minus Date header
  /// 4. Heuristic freshness (if no explicit expiration)
  Duration? calculateFreshnessLifetime(
    CacheEntry entry,
    CacheControl cacheControl,
  ) {
    // Priority 1: s-maxage (shared caches only)
    if (_cacheType == CacheType.shared && cacheControl.sMaxAge != null) {
      return Duration(seconds: cacheControl.sMaxAge!);
    }

    // Priority 2: max-age
    if (cacheControl.maxAge != null) {
      return Duration(seconds: cacheControl.maxAge!);
    }

    // Priority 3: Expires header
    final expires = entry.expiresHeader;
    if (expires != null) {
      final dateValue = entry.dateHeader ?? entry.responseTime;
      final lifetime = expires.difference(dateValue);
      return lifetime.isNegative ? Duration.zero : lifetime;
    }

    // Priority 4: Heuristic freshness
    return _heuristicCalculator.calculateHeuristicFreshness(
      entry,
      cacheControl,
    );
  }

  /// Checks if a cached response is fresh
  /// HTTP caching: A response is fresh if its age hasn't exceeded its freshness lifetime
  bool isFresh(
    CacheEntry entry,
    CacheControl cacheControl, {
    DateTime? now,
  }) {
    final lifetime = calculateFreshnessLifetime(entry, cacheControl);
    if (lifetime == null) {
      // No freshness information available
      return false;
    }

    final age = AgeCalculator.calculateAge(entry, now: now);
    return age <= lifetime;
  }

  /// Checks if a stale response can be served
  /// HTTP caching: Serving Stale Responses
  bool canServeStale(
    CacheEntry entry,
    CacheControl responseCacheControl,
    CacheControl requestCacheControl, {
    bool disconnected = false,
    DateTime? now,
  }) {
    // If explicitly prohibited by must-revalidate or proxy-revalidate
    if (responseCacheControl.mustRevalidate) {
      return false;
    }

    if (_cacheType == CacheType.shared &&
        responseCacheControl.proxyRevalidate) {
      return false;
    }

    // If disconnected and no explicit prohibition, allow stale
    if (disconnected) {
      return true;
    }

    // If request allows max-stale
    if (requestCacheControl.maxStaleAny) {
      return true;
    }

    if (requestCacheControl.maxStale != null) {
      final staleness =
          calculateStaleness(entry, responseCacheControl, now: now);
      if (staleness == null) return false;

      final maxStale = Duration(seconds: requestCacheControl.maxStale!);
      return staleness <= maxStale;
    }

    return false;
  }

  /// Calculates how stale a response is
  /// Returns null if the response is fresh
  Duration? calculateStaleness(
    CacheEntry entry,
    CacheControl cacheControl, {
    DateTime? now,
  }) {
    if (isFresh(entry, cacheControl, now: now)) {
      return null;
    }

    final lifetime = calculateFreshnessLifetime(entry, cacheControl);
    if (lifetime == null) {
      // No freshness information, consider maximally stale
      return const Duration(days: 365);
    }

    final age = AgeCalculator.calculateAge(entry, now: now);
    return age - lifetime;
  }

  /// Checks if a response satisfies the min-fresh requirement
  /// HTTP caching: min-fresh directive
  bool satisfiesMinFresh(
    CacheEntry entry,
    CacheControl responseCacheControl,
    Duration minFresh, {
    DateTime? now,
  }) {
    final lifetime = calculateFreshnessLifetime(entry, responseCacheControl);
    if (lifetime == null) return false;

    final age = AgeCalculator.calculateAge(entry, now: now);
    final remainingFreshness = lifetime - age;

    return remainingFreshness >= minFresh;
  }

  /// Checks if a response satisfies the max-age request directive
  /// HTTP caching: max-age directive
  bool satisfiesMaxAge(
    CacheEntry entry,
    Duration maxAge, {
    DateTime? now,
  }) {
    final age = AgeCalculator.calculateAge(entry, now: now);
    return age <= maxAge;
  }

  /// Determines if validation is required before reusing a response
  bool requiresValidation(
    CacheEntry entry,
    CacheControl responseCacheControl,
    CacheControl requestCacheControl, {
    DateTime? now,
  }) {
    // If response has no-cache, validation required
    if (responseCacheControl.noCache) {
      return true;
    }

    // If request has no-cache, prefer validation
    if (requestCacheControl.requestNoCache) {
      return true;
    }

    // If response is stale and must-revalidate is set
    if (!isFresh(entry, responseCacheControl, now: now)) {
      if (responseCacheControl.mustRevalidate) {
        return true;
      }
      if (_cacheType == CacheType.shared &&
          responseCacheControl.proxyRevalidate) {
        return true;
      }
    }

    return false;
  }

  /// Calculates the freshness lifetime remaining
  /// Useful for debugging and metrics
  Duration? remainingFreshness(
    CacheEntry entry,
    CacheControl cacheControl, {
    DateTime? now,
  }) {
    final lifetime = calculateFreshnessLifetime(entry, cacheControl);
    if (lifetime == null) return null;

    final age = AgeCalculator.calculateAge(entry, now: now);
    final remaining = lifetime - age;

    return remaining.isNegative ? Duration.zero : remaining;
  }
}
