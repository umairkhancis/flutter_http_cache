# Flutter HTTP Cache

A comprehensive HTTP caching library for Flutter with browser-style caching semantics, automatic validation, and intelligent eviction strategies.

## Features

- ✅ **HTTP Standard Compliant** - Full Cache-Control directive support
- ✅ **Smart Storage** - Two-tier caching (memory L1 + disk L2)
- ✅ **Automatic Validation** - ETags and Last-Modified conditional requests
- ✅ **Multiple Eviction Strategies** - LRU, LFU, FIFO, TTL
- ✅ **Offline Support** - Serve stale responses when disconnected
- ✅ **Thread-Safe** - Concurrent request handling

## Installation

```yaml
dependencies:
  flutter_http_cache: ^0.1.0
```

## Quick Start

```dart
import 'package:flutter_http_cache/flutter_http_cache.dart';

// 1. Initialize cache
final cache = HttpCache(
  config: const CacheConfig(
    maxMemorySize: 10 * 1024 * 1024, // 10MB
    maxDiskSize: 50 * 1024 * 1024,   // 50MB
  ),
);
await cache.initialize();

// 2. Create cached HTTP client
final client = CachedHttpClient(cache: cache);

// 3. Make requests (automatically cached)
final response = await client.get(Uri.parse('https://api.example.com/data'));

// 4. Check cache status
print(response.headers['x-cache']); // HIT, MISS, or HIT-STALE
print(response.headers['age']);     // Age in seconds
```

### Configuration

```dart
final cache = HttpCache(
  config: CacheConfig(
    maxMemorySize: 10 * 1024 * 1024,
    maxDiskSize: 50 * 1024 * 1024,
    cacheType: CacheType.private,
    evictionStrategy: EvictionStrategy.lru,
    enableHeuristicFreshness: true,
    serveStaleOnError: true,
    enableLogging: true,
  ),
);
```

### Cache Policies

```dart
// Standard HTTP caching (default)
CachedHttpClient(cache: cache, defaultCachePolicy: CachePolicy.standard);

// Force network
CachedHttpClient(cache: cache, defaultCachePolicy: CachePolicy.networkOnly);

// Offline-first
CachedHttpClient(cache: cache, defaultCachePolicy: CachePolicy.cacheFirst);

// Cache-only
CachedHttpClient(cache: cache, defaultCachePolicy: CachePolicy.cacheOnly);
```

## Dio Integration

For apps already using Dio, simply add the cache interceptor to your existing Dio instance:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

// 1. Initialize cache
final cache = HttpCache(
  config: const CacheConfig(
    enableLogging: true,
  ),
);
await cache.initialize();

// 2. Create Dio with your existing configuration and interceptors
final dio = Dio(BaseOptions(
  baseUrl: 'https://api.example.com',
  connectTimeout: Duration(seconds: 5),
));

// Add your existing interceptors
dio.interceptors.add(LogInterceptor());

// 3. Add the cache interceptor - that's it!
dio.interceptors.add(DioHttpCacheInterceptor(cache));

// 4. Use Dio normally - all requests are automatically cached
final response = await dio.get('/posts/1');

// Optional: Override cache policy per-request
final response = await dio.get(
  '/posts/1',
  options: Options(
    extra: {
      'cachePolicy': CachePolicy.networkFirst,
    },
  ),
);
```

**Key Benefits**:
- ✅ Zero changes to existing Dio code
- ✅ Works with all existing interceptors
- ✅ Per-request cache policy override via `options.extra`
- ✅ Automatic cache invalidation on POST/PUT/DELETE
- ✅ 304 Not Modified handling

See `example/lib/src/demo/dio_interceptor_example.dart` for a complete working example.

## Core Concepts

### Cache-Control Directives

Supports all standard directives: `max-age`, `s-maxage`, `no-cache`, `no-store`, `must-revalidate`, `public`, `private`, `max-stale`, `min-fresh`, etc.

### Freshness & Validation

- **Explicit Expiration**: Uses `max-age`, `s-maxage`, or `Expires` header
- **Heuristic Freshness**: 10% of `Last-Modified` age when no explicit expiration
- **Automatic Validation**: ETags and Last-Modified with conditional requests
- **304 Not Modified**: Updates headers, resets freshness, returns cached body

### Storage Architecture

- **Memory (L1)**: Fast in-memory access with LRU/LFU/FIFO eviction
- **Disk (L2)**: SQLite persistence surviving app restarts
- **Combined**: Auto-promotion to L1, write-through to both tiers

### Cache Management

```dart
await cache.clear();          // Clear entire cache
await cache.clearExpired();   // Clear expired entries only
```

## Architecture

Three-layer design:
- **API Layer**: Public interfaces (`HttpCache`, `CachedHttpClient`, `HttpCacheInterceptor`)
- **Domain Layer**: HTTP caching logic (freshness, validation, age calculation, policies)
- **Data Layer**: Two-tier storage (memory + SQLite disk cache)

Key patterns: Strategy (eviction), Repository (storage), Interceptor (transparent caching)

## Testing

```bash
flutter test
flutter test test/directives/cache_control_test.dart  # Specific test
```

## Example App

See `example/lib/main.dart` for a complete demo with cache policies, statistics, and management.


---

## Manual Cache API (Advanced Use Case)

For scenarios where HTTP headers cannot be modified, this library supports embedding cache metadata in response bodies:

### Response Format
```json
{
  "data": { "vendor": { "id": "123", "name": "Pizza Place" } },
  "cacheMetadata": {
    "cacheControl": "max-age=300, must-revalidate",
    "etag": "\"abc123\"",
    "lastModified": "2024-01-15T12:00:00Z"
  }
}
```

### Usage Pattern
1. **Backend**: Add `cacheMetadata` field to responses (backward compatible)
2. **Client**: Extract metadata, manually call `cache.put()` / `cache.get()`
3. **Repository Pattern**: Create wrapper repositories to automate caching

**Benefits**: HTTP caching semantics without modifying headers, backward compatible, component-level caching support.

See detailed implementation guide in `docs/MANUAL_CACHE_API.md` (or contact maintainers).

## Demo

Run `example/lib/src/demo/main.dart` to see the library in action:

1. **Select cache strategy** (Standard, Cache-First, Network-Only, etc.)
2. **First request**: Cache MISS, full network latency
3. **Second request**: Cache HIT, near-instant response
4. **View statistics**: Entry count, cache size, hit/miss ratio

Screenshots demonstrating cache behavior:

| Initial Request (Cache MISS) | Cached Request (Cache HIT) |
|------------------------------|----------------------------|
| <img width="540" alt="Cache Miss" src="https://github.com/user-attachments/assets/d18ff078-b56d-4ee2-910a-142131b88a2a" /> | <img width="540" alt="Cache Hit" src="https://github.com/user-attachments/assets/8421e83b-db12-4b1f-a963-8944a4971048" /> |

---

## License

MIT License - see LICENSE file for details.

## Support

For issues or questions, please file an issue on GitHub.
