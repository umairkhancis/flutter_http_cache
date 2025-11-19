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
  flutter_http_cache: ^0.0.2
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

### For Apps Already Using Dio

If your app already uses Dio, adding HTTP caching is just **one line of code**! The cache interceptor integrates seamlessly with your existing Dio setup.

#### Step-by-Step Integration

```dart
import 'package:dio/dio.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

// Step 1: Initialize the cache (do this once at app startup)
final cache = HttpCache(
  config: const CacheConfig(
    maxMemorySize: 10 * 1024 * 1024,  // 10MB memory cache
    maxDiskSize: 50 * 1024 * 1024,    // 50MB disk cache
    enableLogging: true,               // See cache hits/misses
    serveStaleOnError: true,           // Offline support
  ),
);
await cache.initialize();

// Step 2: Add the interceptor to your existing Dio instance
// Keep all your existing configuration and interceptors!
final dio = Dio(BaseOptions(
  baseUrl: 'https://api.example.com',
  connectTimeout: Duration(seconds: 5),
  receiveTimeout: Duration(seconds: 3),
));

// Your existing interceptors continue to work
dio.interceptors.add(LogInterceptor());
dio.interceptors.add(AuthInterceptor());  // Your custom interceptors

// Add the cache interceptor - that's it!
dio.interceptors.add(DioHttpCacheInterceptor(cache));

// Step 3: Use Dio normally - caching is automatic!
final response = await dio.get('/posts/1');
print(response.headers.value('x-cache'));  // HIT, MISS, or HIT-STALE
```

#### How It Works

The `DioHttpCacheInterceptor` is a standard Dio interceptor that:

1. **Checks cache before network request** - Returns cached data if fresh
2. **Validates stale cache** - Sends conditional requests (If-None-Match, If-Modified-Since)
3. **Handles 304 responses** - Updates cache metadata, returns cached body
4. **Stores successful responses** - Automatically caches GET requests
5. **Invalidates on mutations** - Clears related cache on POST/PUT/DELETE

**All of this happens automatically with zero changes to your existing code!**

#### Per-Request Cache Control

Override cache behavior for specific requests using `options.extra`:

```dart
// Force network request (bypass cache)
await dio.get(
  '/users/profile',
  options: Options(
    extra: {'cachePolicy': CachePolicy.networkOnly},
  ),
);

// Try cache first, fallback to network
await dio.get(
  '/settings',
  options: Options(
    extra: {'cachePolicy': CachePolicy.cacheFirst},
  ),
);

// Network first, fallback to stale cache on error (great for offline support)
await dio.get(
  '/products',
  options: Options(
    extra: {'cachePolicy': CachePolicy.networkFirst},
  ),
);

// Cache only (never make network request)
await dio.get(
  '/offline-data',
  options: Options(
    extra: {'cachePolicy': CachePolicy.cacheOnly},
  ),
);
```

#### Available Cache Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `CachePolicy.standard` | HTTP standard caching (respects Cache-Control headers) | Default, works like browser cache |
| `CachePolicy.networkOnly` | Always fetch from network, store in cache | Force refresh |
| `CachePolicy.networkFirst` | Network first, serve stale on error | Offline support |
| `CachePolicy.cacheFirst` | Cache first, network if not cached | Offline-first apps |
| `CachePolicy.cacheOnly` | Never make network request | Offline mode |

#### Response Data Handling

**Important**: Cached responses return data in the **same format** as network responses:

```dart
// Both network and cache return decoded JSON
final response = await dio.get('/posts/1');
print(response.data['title']);  // Works for both cache hit and miss!

// Supported response types:
// ✅ JSON objects/arrays (auto-parsed)
// ✅ Plain text strings
// ✅ Binary data (images, files)
```

The interceptor automatically decodes cached responses to match Dio's normal behavior, so your app code works identically whether the response came from cache or network.

#### Cache Management

```dart
// Check cache statistics
final stats = await cache.getStats();
print('Cache entries: ${stats['entries']}');
print('Cache size: ${stats['bytesFormatted']}');

// Clear entire cache
await cache.clear();

// Clear only expired entries
await cache.clearExpired();

// Don't forget to close the cache when done (e.g., app disposal)
await cache.close();
```

#### Advanced: Cache Headers for Debugging

Every response includes cache debugging headers:

```dart
final response = await dio.get('/data');

// Check cache status
print(response.headers.value('x-cache'));
// "HIT" = served from cache
// "MISS" = network request
// "HIT-STALE" = served stale cache

// Check age
print(response.headers.value('age'));
// Age in seconds (0 for fresh responses)

// Check warnings (for stale responses)
print(response.headers.value('warning'));
// e.g., "110 - Response is Stale"
```

#### Key Benefits

- ✅ **Zero breaking changes** - Works with existing code
- ✅ **Works with all interceptors** - Compatible with auth, logging, retry, etc.
- ✅ **Per-request control** - Override cache policy per request
- ✅ **Automatic invalidation** - POST/PUT/DELETE clear related cache
- ✅ **304 Not Modified** - Efficient revalidation
- ✅ **Offline support** - Serve stale cache on network errors
- ✅ **Type-safe** - Same response data format as network
- ✅ **Transparent** - App logic doesn't need to know about caching

#### Complete Working Example

See `example/lib/src/demo/dio_interceptor_example.dart` for a full Flutter app demonstrating:
- Multiple cache policies
- Cache statistics display
- Network error handling
- POST request cache invalidation
- Real-time cache status indicators

#### Migration from Other Cache Solutions

If you're migrating from another cache library:

```dart
// Before: Using dio_cache_interceptor or dio_http_cache
dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));

// After: Using flutter_http_cache
dio.interceptors.add(DioHttpCacheInterceptor(cache));

// That's it! Your existing Dio code continues to work unchanged.
```

**Why switch?**
- ✅ Full HTTP standard compliance (Cache-Control, ETags, etc.)
- ✅ Two-tier storage (memory + disk)
- ✅ Multiple eviction strategies (LRU, LFU, FIFO, TTL)
- ✅ Better offline support (serve stale on error)
- ✅ Proper response decoding (JSON auto-parsed from cache)
- ✅ Active maintenance and comprehensive tests

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
