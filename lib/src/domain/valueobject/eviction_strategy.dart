/// Eviction strategy for when cache reaches size limits
enum EvictionStrategy {
  /// Least Recently Used - evict entries that haven't been accessed recently
  lru,

  /// Least Frequently Used - evict entries that are accessed least often
  lfu,

  /// First In First Out - evict oldest entries first
  fifo,

  /// Time-based - evict entries closest to expiration
  ttl,
}
