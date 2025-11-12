/// Cache type: private (single-user) or shared (multi-user)
/// Affects handling of certain directives like 'private' and 's-maxage'
enum CacheType {
  /// Private cache (e.g., browser cache, mobile app cache)
  /// Respects both 'private' and 'public' directives
  private,

  /// Shared cache (e.g., proxy cache, CDN)
  /// Must not store responses with 'private' directive
  shared,
}
