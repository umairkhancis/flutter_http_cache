/// Cache policy for individual requests
enum CachePolicy {
  /// Use cache if available and fresh, otherwise network
  /// This is the default HTTP caching standard compliant behavior
  standard,

  /// Always use network, bypass cache
  /// Forces revalidation
  networkOnly,

  /// Use cache if available (even if stale), fallback to network
  /// Useful for offline-first scenarios
  cacheFirst,

  /// Only use cache, fail if not available
  /// Corresponds to 'only-if-cached' directive
  cacheOnly,

  /// Use network first, fallback to cache on error (even if stale)
  /// Useful for poor connectivity scenarios
  networkFirst,
}
