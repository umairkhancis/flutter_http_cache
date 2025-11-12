# Flutter HTTP Cache

A comprehensive HTTP caching library for Flutter applications. This library implements browser-style HTTP caching with support for all standard Cache-Control directives, validation, freshness calculation, and intelligent cache eviction strategies.

## Features

- ✅ **HTTP Caching Standard Compliant** - Full implementation of modern HTTP caching semantics
- ✅ **Cache-Control Support** - All standard directives (max-age, no-cache, must-revalidate, etc.)
- ✅ **Freshness Calculation** - Automatic freshness determination with heuristic support
- ✅ **Validation & Revalidation** - ETags and Last-Modified conditional requests
- ✅ **Smart Storage** - Two-tier caching with memory (L1) and disk (L2) storage
- ✅ **Cache Invalidation** - Automatic invalidation on unsafe methods (POST, PUT, DELETE)
- ✅ **Vary Header Support** - Request header matching for cache key generation
- ✅ **Multiple Eviction Strategies** - LRU, LFU, FIFO, TTL
- ✅ **Offline Support** - Serve stale responses when disconnected
- ✅ **Thread-Safe** - Concurrent request handling with proper synchronization

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_http_cache: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Basic Usage

```dart
import 'package:flutter_http_cache/flutter_http_cache.dart';

// 1. Create and initialize cache
final cache = HttpCache(
  config: const CacheConfig(
    maxMemorySize: 10 * 1024 * 1024,  // 10MB
    maxDiskSize: 50 * 1024 * 1024,    // 50MB
  ),
);

await cache.initialize();

// 2. Create cached HTTP client
final client = CachedHttpClient(cache: cache);

// 3. Make requests (automatically cached)
final response = await client.get(
  Uri.parse('https://api.example.com/data'),
);

// 4. Check cache status
print(response.headers['x-cache']);  // HIT, MISS, or HIT-STALE
print(response.headers['age']);      // Age in seconds
```

### Advanced Configuration

```dart
final cache = HttpCache(
  config: CacheConfig(
    // Storage limits
    maxMemorySize: 10 * 1024 * 1024,
    maxMemoryEntries: 100,
    maxDiskSize: 50 * 1024 * 1024,
    maxDiskEntries: 1000,

    // Cache type
    cacheType: CacheType.private,  // or CacheType.shared

    // Eviction strategy
    evictionStrategy: EvictionStrategy.lru,  // LRU, LFU, FIFO, TTL

    // Heuristic freshness
    enableHeuristicFreshness: true,
    heuristicFreshnessPercent: 0.10,  // 10% of Last-Modified age
    maxHeuristicFreshness: Duration(days: 7),

    // Stale response handling
    serveStaleOnError: true,
    maxStaleAge: Duration(days: 1),

    // Privacy (timing attack mitigation)
    doubleKeyCache: false,

    // Debug
    enableLogging: true,
  ),
);
```

### Cache Policies

Control caching behavior per request:

```dart
// Standard HTTP caching behavior (default)
final client = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.standard,
);

// Force network (bypass cache)
final networkClient = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.networkOnly,
);
final freshData = await networkClient.get(uri);

// Offline-first (prefer cache)
final cachedFirst = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.cacheFirst,
);

// Cache-only (fail if not cached)
final offlineOnly = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.cacheOnly,
);

// Network-first with stale fallback
final networkFirst = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.networkFirst,
);
```

## Core Concepts

### Cache-Control Directives

The library supports all standard HTTP Cache-Control directives:

**Response Directives:**
- `max-age` - Explicit freshness lifetime
- `s-maxage` - Freshness for shared caches (CDN, proxy)
- `no-cache` - Must validate before reuse
- `no-store` - Do not store
- `must-revalidate` - Prohibit stale responses
- `proxy-revalidate` - Shared cache must revalidate
- `public` - Explicitly cacheable
- `private` - Only private caches can store
- `no-transform` - Do not modify content

**Request Directives:**
- `max-age` - Prefer responses younger than age
- `max-stale` - Accept stale responses
- `min-fresh` - Prefer responses fresh for duration
- `no-cache` - Prefer validation
- `only-if-cached` - Return cached or 504

### Freshness Calculation

The library implements HTTP caching freshness calculation:

1. **Explicit Expiration** (in priority order):
   - `s-maxage` (shared caches only)
   - `max-age`
   - `Expires` header

2. **Heuristic Freshness** (when no explicit expiration):
   - Uses `Last-Modified` header (default: 10% of modification age)
   - Only for heuristically cacheable status codes
   - Configurable maximum duration

3. **Age Calculation**:
```
apparent_age = max(0, response_time - date_value)
response_delay = response_time - request_time
corrected_age_value = age_value + response_delay
corrected_initial_age = max(apparent_age, corrected_age_value)
resident_time = now - response_time
current_age = corrected_initial_age + resident_time
```

### Validation & Revalidation

When cached responses become stale, the library automatically validates them:

**Validators:**
- `ETag` - Strong validator (exact match required)
- `Last-Modified` - Weak validator (timestamp-based)

**Conditional Requests:**
- `If-None-Match` - Generated from ETag
- `If-Modified-Since` - Generated from Last-Modified

**304 Not Modified:**
- Updates cached headers
- Resets freshness lifetime
- Returns cached body

### Cache Invalidation

Automatic invalidation on unsafe methods:

- **Target URI** - Always invalidated on successful PUT/POST/DELETE
- **Location Header** - Optionally invalidated (same-origin only)
- **Content-Location** - Optionally invalidated (same-origin only)

Manual cache management:

```dart
// Clear entire cache
await cache.clear();

// Clear expired entries
await cache.clearExpired();
```

### Storage Architecture

**Two-Tier Storage:**

1. **Memory Storage (L1)**
   - Fast in-memory access
   - Configurable size limit
   - LRU/LFU/FIFO eviction

2. **Disk Storage (L2)**
   - SQLite-based persistence
   - Survives app restarts
   - Larger capacity

3. **Combined Storage**
   - Automatic promotion to L1 on access
   - Write-through to both tiers
   - Memory pressure handling

### Vary Header Support

The library properly handles `Vary` headers for request-specific caching:

```dart
// Server response:
// Vary: Accept-Encoding, Accept-Language

// Different cache entries for:
// 1. Accept-Encoding: gzip, Accept-Language: en
// 2. Accept-Encoding: br, Accept-Language: es

// Vary: * means never match (uncacheable)
```

## Project Structure

The library follows a clean, layered architecture organized into three main layers:

```
lib/
├── flutter_http_cache.dart          # Public API exports
└── src/
    ├── api/                          # Application layer - public interfaces
    │   ├── cache.dart                  # HttpCache - main cache orchestrator
    │   ├── cache_config.dart           # CacheConfig - configuration options
    │   ├── cached_http_client.dart     # CachedHttpClient - HTTP client wrapper
    │   └── http_cache_interceptor.dart # HttpCacheInterceptor - request/response interceptor
    │
    ├── domain/                       # Domain layer - business logic
    │   ├── service/                    # Domain services
    │   │   ├── age_calculator.dart       # Age calculation algorithm
    │   │   ├── cache_key_generator.dart  # Cache key generation with Vary support
    │   │   ├── cache_policy.dart         # Policy decisions (storability & reusability)
    │   │   ├── freshness.dart            # Freshness calculation
    │   │   ├── header_utils.dart         # HTTP header utilities
    │   │   ├── heuristic.dart            # Heuristic freshness (10% rule)
    │   │   ├── invalidation.dart         # Cache invalidation on unsafe methods
    │   │   └── validator.dart            # Validation and conditional requests
    │   │
    │   └── valueobject/                # Value objects (immutable domain entities)
    │       ├── cache_control.dart        # Cache-Control directive parsing
    │       ├── cache_entry.dart          # Cached response representation
    │       ├── cache_policy.dart         # Cache policy enum
    │       ├── cache_type.dart           # Private/Shared cache type
    │       └── eviction_strategy.dart    # LRU/LFU/FIFO/TTL strategies
    │
    └── data/                         # Data layer - storage implementations
        ├── storage.dart                  # CacheStorage interface
        └── impl/                         # Storage implementations
            ├── combined_storage.dart       # Two-tier L1/L2 coordinator
            ├── memory_storage.dart         # L1 in-memory cache
            └── disk_storage.dart           # L2 SQLite persistent cache
```

### Architecture Highlights

**Layered Design:**
- **API Layer**: Public interfaces and HTTP client integration
- **Domain Layer**: HTTP caching business logic, completely framework-agnostic
- **Data Layer**: Pluggable storage backends with two-tier architecture

**Key Patterns:**
- **Value Objects**: Immutable, validated domain entities (CacheEntry, CacheControl)
- **Strategy Pattern**: Pluggable eviction strategies (LRU, LFU, FIFO, TTL)
- **Repository Pattern**: Abstract CacheStorage interface with multiple implementations
- **Interceptor Pattern**: HttpCacheInterceptor for transparent caching

**HTTP Caching Components:**
- `CachePolicyDecisions` - Storability & reusability decisions
- `FreshnessCalculator` + `AgeCalculator` + `HeuristicFreshnessCalculator` - Freshness determination
- `CacheValidator` - Conditional requests and validation
- `CacheInvalidation` - Unsafe method handling
- `CacheControl` - Directive parsing

## API Reference

### HttpCache

Main cache interface.

```dart
// Initialize
await cache.initialize();

// Get cached response
final cached = await cache.get(
  method: 'GET',
  uri: uri,
  requestHeaders: headers,
  policy: CachePolicy.standard,
);

// Store response
await cache.put(
  method: 'GET',
  uri: uri,
  statusCode: 200,
  requestHeaders: requestHeaders,
  responseHeaders: responseHeaders,
  body: bodyBytes,
  requestTime: requestTime,
  responseTime: responseTime,
);

// Get statistics
final stats = await cache.getStats();
// { entries: 42, bytes: 1048576, bytesFormatted: "1.00 MB" }

// Close cache
await cache.close();
```

### CachedHttpClient

HTTP client with automatic caching.

```dart
final client = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.standard,
);

// Standard HTTP methods
final response = await client.get(uri);
await client.post(uri, body: data);
await client.put(uri, body: data);
await client.delete(uri);

// Close client
client.close();
```

### CacheConfig

Configuration options.

```dart
const config = CacheConfig(
  maxMemorySize: 10 * 1024 * 1024,      // 10MB
  maxMemoryEntries: 100,
  maxDiskSize: 50 * 1024 * 1024,        // 50MB
  maxDiskEntries: 1000,
  cacheType: CacheType.private,
  evictionStrategy: EvictionStrategy.lru,
  enableHeuristicFreshness: true,
  heuristicFreshnessPercent: 0.10,
  maxHeuristicFreshness: Duration(days: 7),
  serveStaleOnError: true,
  maxStaleAge: Duration(days: 1),
  doubleKeyCache: false,
  databasePath: '/custom/path/cache.db',
  enableLogging: false,
);
```

## Testing

Run tests:

```bash
flutter test
```

Run specific test file:

```bash
flutter test test/directives/cache_control_test.dart
```

## Performance Considerations

1. **Memory Usage** - Configure appropriate memory limits based on device
2. **Disk Usage** - Monitor and clear expired entries periodically
3. **Concurrency** - Thread-safe operations with synchronized locks
4. **Eviction** - Choose appropriate strategy (LRU recommended for most cases)

## HTTP Caching Compliance

This library implements modern HTTP Caching semantics:

- ✅ Storing Responses in Caches
- ✅ Constructing Responses from Caches
- ✅ Freshness Calculation
- ✅ Validation & Conditional Requests
- ✅ Cache Invalidation
- ✅ Cache-Control Directives
- ✅ Security Considerations

## Example App

See [example/lib/main.dart](example/lib/main.dart) for a complete Flutter app demonstrating:

- Basic caching
- Different cache policies
- Cache statistics
- Cache management (clear, clear expired)

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Implements modern HTTP Caching semantics
- Follows HTTP protocol standards
- Inspired by browser caching implementations

## Support

For issues, questions, or suggestions, please file an issue on GitHub.
