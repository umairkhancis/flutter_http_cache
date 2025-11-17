# Flutter HTTP Cache

A comprehensive HTTP caching library for Flutter applications. This library implements browser-style
HTTP caching with support for all standard Cache-Control directives, validation, freshness
calculation, and intelligent cache eviction strategies.

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


## Demo

### Step 1: Run the `example/lib/src/demo/main.dart`

<img width="1080" height="2400" alt="Screenshot_20251117_141325" src="https://github.com/user-attachments/assets/b1881dcb-eb1b-4af4-8aec-e86e9a7b7b39" />

### Step 2: Use example curl command

<img width="1080" height="2400" alt="Screenshot_20251117_141353" src="https://github.com/user-attachments/assets/69a891bb-8ddb-4249-aba2-40de0b636721" />

### Step 3: Select your strategy according to your use case.

<img width="1080" height="2400" alt="Screenshot_20251117_141414" src="https://github.com/user-attachments/assets/656e4913-4401-41ee-9788-29ac377183db" />

### Step 4: Observe entries count before hitting the request button and after hitting request button there is a Cache Miss and Latency is as per the network, as it is a first time call.

<img width="1080" height="2400" alt="Screenshot_20251117_141428" src="https://github.com/user-attachments/assets/d18ff078-b56d-4ee2-910a-142131b88a2a" />

### Step 5: Observe there is a Cache Hit now and Latency is very low, as it is a second call and served from the cache.

<img width="1080" height="2400" alt="Screenshot_20251117_141436" src="https://github.com/user-attachments/assets/8421e83b-db12-4b1f-a963-8944a4971048" />






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
    maxMemorySize: 10 * 1024 * 1024, // 10MB
    maxDiskSize: 50 * 1024 * 1024, // 50MB
  ),
);

await
cache.initialize
();

// 2. Create cached HTTP client
final client = CachedHttpClient(cache: cache);

// 3. Make requests (automatically cached)
final response = await
client.get
(
Uri.parse('https://api.example.com/data'),
);

// 4. Check cache status
print(response.headers['x-cache']); // HIT, MISS, or HIT-STALE
print(response.headers['age'
]
); // Age in seconds
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
    cacheType: CacheType.private,
    // or CacheType.shared

    // Eviction strategy
    evictionStrategy: EvictionStrategy.lru,
    // LRU, LFU, FIFO, TTL

    // Heuristic freshness
    enableHeuristicFreshness: true,
    heuristicFreshnessPercent: 0.10,
    // 10% of Last-Modified age
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
final freshData = await
networkClient.get
(
uri);

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
await
cache.clear
();

// Clear expired entries
await
cache.clearExpired
();
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
await
cache.initialize
();

// Get cached response
final cached = await
cache.get
(
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
await
cache
.
close
(
);
```

### CachedHttpClient

HTTP client with automatic caching.

```dart

final client = CachedHttpClient(
  cache: cache,
  defaultCachePolicy: CachePolicy.standard,
);

// Standard HTTP methods
final response = await
client.get
(
uri);
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
  maxMemorySize: 10 * 1024 * 1024,
  // 10MB
  maxMemoryEntries: 100,
  maxDiskSize: 50 * 1024 * 1024,
  // 50MB
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

See [example/lib/main.dart](example/main.dart) for a complete Flutter app demonstrating:

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


# Pivotal Roadmap for Talabat Needs: Manual Cache API Usage Plan

## Using HTTP Caching Standards Without HTTP Headers

### Problem Statement

**Constraint**: Existing backend cannot be changed (API design frozen)
**Requirement**: Add caching with HTTP standards compliance
**Solution**: Embed cache metadata in response body instead of HTTP headers
**Goal**: Use cache API manually while following HTTP caching semantics

---

## Current Backend Response (Cannot Change)

```json
{
  "data": {
    "vendor": {
      "id": "123",
      "name": "Pizza Place",
      "isOpen": true
    }
  }
}
```

## New Backend Response (Backward Compatible)

```json
{
  "data": {
    "vendor": {
      "id": "123",
      "name": "Pizza Place",
      "isOpen": true
    }
  },
  "cacheMetadata": {
    "cacheControl": "max-age=300, must-revalidate",
    "etag": "\"abc123\"",
    "lastModified": "2024-01-15T12:00:00Z",
    "vary": "Accept-Language",
    "date": "2024-01-15T12:05:00Z"
  }
}
```

**Backward Compatibility**: Old clients ignore `cacheMetadata`, new clients use it.

---

## Architecture Plan

### Option 1: Direct Cache API Usage (Recommended)

```
┌─────────────────────────────────────────────┐
│           Application Layer                 │
│                                             │
│  1. Make HTTP request (existing client)    │
│  2. Parse response JSON                     │
│  3. Extract cacheMetadata node             │
│  4. Manually call cache.put()              │
│  5. On next request, call cache.get()      │
└─────────────────┬───────────────────────────┘
                  │
                  │ Uses CacheEntry API
                  │
┌─────────────────▼───────────────────────────┐
│         HttpCache (Current Library)         │
│                                             │
│  • cache.put() - Store manually            │
│  • cache.get() - Retrieve manually         │
│  • Uses CacheEntry, CacheControl           │
│  • All caching logic (age, freshness)     │
└─────────────────────────────────────────────┘
```

### Option 2: Wrapper Repository Pattern

```
┌─────────────────────────────────────────────┐
│      CacheableRepository<T> (New)          │
│                                             │
│  • Wraps existing HTTP client              │
│  • Extracts cacheMetadata from body        │
│  • Delegates to HttpCache internally       │
│  • Returns domain models (not HTTP)        │
└─────────────────┬───────────────────────────┘
                  │
                  │ Uses
                  │
┌─────────────────▼───────────────────────────┐
│         HttpCache (Current Library)         │
└─────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Backend Changes (1 week)

#### Week 1: Add Cache Metadata to Responses

**Task 1.1: Define Cache Metadata Schema**

```json
{
  "cacheMetadata": {
    // Required
    "cacheControl": "max-age=300",
    // Optional validators
    "etag": "\"version-123\"",
    "lastModified": "2024-01-15T12:00:00Z",
    // Optional
    "vary": "Accept-Language",
    "date": "2024-01-15T12:05:00Z",
    "age": 10,
    "expires": "2024-01-15T12:10:00Z"
  }
}
```

**Task 1.2: Update Backend Endpoints**

Add `cacheMetadata` to responses (endpoint by endpoint):

```python
# Backend (example)
def get_vendor(vendor_id):
    vendor = db.get_vendor(vendor_id)

    return {
        "data": vendor.to_dict(),
        "cacheMetadata": {
            "cacheControl": "max-age=300",  # 5 minutes
            "etag": f'"{vendor.version}"',
            "lastModified": vendor.updated_at.isoformat(),
        }
    }
```

**Rollout Strategy**:

- Add `cacheMetadata` to 1 endpoint (test)
- Monitor for 1 week
- Gradual rollout to all endpoints

**Task 1.3: Business-Specific Cache Rules**

```python
# Different endpoints, different policies
CACHE_POLICIES = {
    "/vendors/{id}/availability": {
        "cache_control": "max-age=30",  # 30 seconds
        "must_revalidate": True,
    },
    "/vendors/{id}/menu": {
        "cache_control": "max-age=21600",  # 6 hours
        "stale_while_revalidate": 3600,
    },
    "/vendors/{id}/static": {
        "cache_control": "max-age=86400",  # 1 day
        "immutable": True,
    },
}
```

---

### Phase 2: Client-Side Manual Cache Integration (2 weeks)

#### Week 2: Core Manual Cache API

**Task 2.1: Expose Manual Cache API**

Check if current library already supports this (it should):

```dart
// lib/src/api/cache.dart - Check these methods exist
class HttpCache {
  // Manual PUT
  Future<void> putManual({
    required String key,
    required Map<String, dynamic> data,
    required Map<String, String> cacheMetadata,
    DateTime? requestTime,
    DateTime? responseTime,
  });

  // Manual GET
  Future<CachedData?> getManual(String key);

  // Manual DELETE
  Future<void> deleteManual(String key);
}
```

**If not exists, create wrapper**:

```dart
// lib/src/api/manual_cache_api.dart
class ManualCacheAPI {
  final HttpCache _httpCache;

  ManualCacheAPI(this._httpCache);

  /// Store data manually with cache metadata from response body
  Future<void> put({
    required String key,
    required dynamic data,
    required CacheMetadata metadata,
  }) async {
    // Convert metadata to CacheEntry
    final entry = CacheEntry(
      method: 'MANUAL',
      // Pseudo method
      uri: Uri.parse(key),
      statusCode: 200,
      headers: _buildHeadersFromMetadata(metadata),
      body: _serializeData(data),
      requestTime: DateTime.now(),
      responseTime: metadata.date ?? DateTime.now(),
    );

    // Store using internal cache API
    await _httpCache.putEntry(key, entry);
  }

  /// Retrieve cached data
  Future<CachedData?> get(String key) async {
    final entry = await _httpCache.getEntry(key);

    if (entry == null) return null;

    // Check freshness using existing logic
    final cacheControl = CacheControl.parse(
      entry.headers['cache-control'],
    );

    final isFresh = _httpCache.isFresh(entry, cacheControl);

    return CachedData(
      data: _deserializeData(entry.body),
      isFresh: isFresh,
      age: _httpCache.calculateAge(entry),
      requiresValidation: !isFresh && _shouldRevalidate(cacheControl),
    );
  }

  Map<String, String> _buildHeadersFromMetadata(CacheMetadata metadata) {
    return {
      if (metadata.cacheControl != null)
        'cache-control': metadata.cacheControl!,
      if (metadata.etag != null)
        'etag': metadata.etag!,
      if (metadata.lastModified != null)
        'last-modified': metadata.lastModified!.toIso8601String(),
      if (metadata.vary != null)
        'vary': metadata.vary!,
      if (metadata.date != null)
        'date': metadata.date!.toIso8601String(),
      if (metadata.age != null)
        'age': metadata.age.toString(),
    };
  }
}
```

**Task 2.2: Create Data Models**

```dart
// lib/src/api/cache_metadata.dart
class CacheMetadata {
  final String? cacheControl;
  final String? etag;
  final DateTime? lastModified;
  final String? vary;
  final DateTime? date;
  final int? age;
  final DateTime? expires;

  CacheMetadata({
    this.cacheControl,
    this.etag,
    this.lastModified,
    this.vary,
    this.date,
    this.age,
    this.expires,
  });

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      cacheControl: json['cacheControl'] as String?,
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
      vary: json['vary'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : null,
      age: json['age'] as int?,
      expires: json['expires'] != null
          ? DateTime.parse(json['expires'] as String)
          : null,
    );
  }
}

class CachedData<T> {
  final T data;
  final bool isFresh;
  final Duration age;
  final bool requiresValidation;

  CachedData({
    required this.data,
    required this.isFresh,
    required this.age,
    required this.requiresValidation,
  });
}
```

#### Week 3: Repository Pattern Implementation

**Task 2.3: Create CacheableRepository**

```dart
// lib/src/repositories/cacheable_repository.dart
abstract class CacheableRepository<T> {
  final http.Client httpClient;
  final ManualCacheAPI cache;

  CacheableRepository({
    required this.httpClient,
    required this.cache,
  });

  /// Override: Generate cache key from request
  String generateCacheKey(String endpoint, Map<String, dynamic>? params);

  /// Override: Parse response and extract data
  T parseData(Map<String, dynamic> responseBody);

  /// Override: Extract cache metadata from response
  CacheMetadata? extractCacheMetadata(Map<String, dynamic> responseBody);

  /// Override: Build validation headers for revalidation
  Map<String, String> buildValidationHeaders(CachedData<T> cached);

  /// Standard fetch with caching
  Future<T> fetch(String endpoint, {
    Map<String, dynamic>? params,
    CacheStrategy strategy = CacheStrategy.standard,
  }) async {
    final cacheKey = generateCacheKey(endpoint, params);

    // 1. Try cache first
    final cached = await cache.get(cacheKey);

    if (cached != null) {
      if (cached.isFresh) {
        // Cache hit - fresh
        return cached.data as T;
      }

      if (strategy == CacheStrategy.cacheFirst) {
        // Use stale if strategy allows
        return cached.data as T;
      }

      if (cached.requiresValidation) {
        // Conditional request
        return await _revalidate(endpoint, params, cached as CachedData<T>);
      }
    }

    // 2. Cache miss or requires fresh fetch
    return await _fetchAndCache(endpoint, params);
  }

  Future<T> _fetchAndCache(String endpoint,
      Map<String, dynamic>? params,) async {
    // Make HTTP request
    final response = await httpClient.get(
      Uri.parse(endpoint).replace(queryParameters: params),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract data and metadata
    final data = parseData(json);
    final metadata = extractCacheMetadata(json);

    // Cache if metadata present
    if (metadata != null) {
      await cache.put(
        key: generateCacheKey(endpoint, params),
        data: data,
        metadata: metadata,
      );
    }

    return data;
  }

  Future<T> _revalidate(String endpoint,
      Map<String, dynamic>? params,
      CachedData<T> cached,) async {
    // Build conditional request
    final headers = buildValidationHeaders(cached);

    final response = await httpClient.get(
      Uri.parse(endpoint).replace(queryParameters: params),
      headers: headers,
    );

    if (response.statusCode == 304) {
      // Not Modified - use cached
      // Update cache metadata (age, etc.)
      final metadata = extractCacheMetadata(
        jsonDecode(response.body),
      );

      if (metadata != null) {
        await cache.put(
          key: generateCacheKey(endpoint, params),
          data: cached.data,
          metadata: metadata,
        );
      }

      return cached.data;
    }

    // Full response - replace cache
    return await _fetchAndCache(endpoint, params);
  }
}
```

**Task 2.4: Concrete Repository Example**

```dart
// app/repositories/vendor_repository.dart
class VendorRepository extends CacheableRepository<Vendor> {
  VendorRepository({
    required super.httpClient,
    required super.cache,
  });

  @override
  String generateCacheKey(String endpoint, Map<String, dynamic>? params) {
    return endpoint; // Simple key, or add params
  }

  @override
  Vendor parseData(Map<String, dynamic> responseBody) {
    return Vendor.fromJson(responseBody['data']['vendor']);
  }

  @override
  CacheMetadata? extractCacheMetadata(Map<String, dynamic> responseBody) {
    final metadata = responseBody['cacheMetadata'];
    if (metadata == null) return null;

    return CacheMetadata.fromJson(metadata);
  }

  @override
  Map<String, String> buildValidationHeaders(CachedData<Vendor> cached) {
    final headers = <String, String>{};

    // Add If-None-Match if ETag present
    // (Extract from original metadata)

    return headers;
  }

  // Business methods
  Future<Vendor> getVendor(String vendorId) async {
    return fetch('/vendors/$vendorId');
  }

  Future<Vendor> getVendorAvailability(String vendorId) async {
    return fetch(
      '/vendors/$vendorId/availability',
      strategy: CacheStrategy.cacheFirst, // Offline-first
    );
  }
}
```

---

### Phase 3: Usage Examples (1 week)

#### Week 4: Integration & Testing

**Task 3.1: Basic Usage**

```dart
// Initialize cache
final cache = HttpCache(
  config: CacheConfig(
    maxMemorySize: 10 * 1024 * 1024,
    maxDiskSize: 50 * 1024 * 1024,
  ),
);
await
cache.initialize
();

// Create manual API
final manualCache = ManualCacheAPI(cache);

// Create repository
final vendorRepo = VendorRepository(
  httpClient: http.Client(),
  cache: manualCache,
);

// Usage
final vendor = await
vendorRepo.getVendor
('123
'
);
// Automatically cached based on cacheMetadata from response
```

**Task 3.2: Advanced Usage - Component Caching**

```dart
// Response with component-level metadata
{
"data": {
"vendor": {
"name": "Pizza Place",
"isOpen": true,
"menu": [...]
}
},
"cacheMetadata": {
"components": {
"$.vendor.name": {
"cacheControl": "max-age=86400" // 1 day
},
"$.vendor.isOpen": {
"cacheControl": "max-age=30" // 30 seconds
},
"$.vendor.menu": {
"cacheControl": "max-age=21600" // 6 hours
}
}
}
}

// Repository implementation
class ComponentAwareVendorRepository extends CacheableRepository<Vendor> {
@override
Future<Vendor> fetch(String endpoint, {Map<String, dynamic>? params}) async {
// 1. Fetch response
final response = await httpClient.get(Uri.parse(endpoint));
final json = jsonDecode(response.body);

// 2. Extract component metadata
final componentMetadata = json['cacheMetadata']?['components'];

if (componentMetadata != null) {
// 3. Cache each component separately
for (final entry in componentMetadata.entries) {
final jsonPath = entry.key;
final metadata = CacheMetadata.fromJson(entry.value);

// Extract component data using JsonPath
final componentData = JsonPath(jsonPath).read(json['data']).first.value;

// Cache component
await cache.put(
key: '$endpoint:$jsonPath',
data: componentData,
metadata: metadata,
);
}
}

// 4. Return full object
return parseData(json);
}

// Get specific component
Future<bool> getVendorAvailability(String vendorId) async {
final cached = await cache.get('/vendors/$vendorId:\$.vendor.isOpen');

if (cached != null && cached.isFresh) {
return cached.data as bool;
}

// Fetch full vendor if component not cached
final vendor = await getVendor(vendorId);
return vendor.isOpen;
}
}
```

**Task 3.3: Validation & Revalidation**

```dart
// Backend returns ETag in cacheMetadata
{
"data": {...},
"cacheMetadata": {
"cacheControl": "max-age=300, must-revalidate",
"etag": "\"version-456\""
}
}

// Repository handles validation
@override
Future<Vendor> _revalidate(...) async {
// Extract ETag from cached metadata
final cachedEtag = /* extract from cache */;

// Make conditional request
final response = await httpClient.get(
uri,
headers: {'if-none-match': cachedEtag},
);

// Backend checks If-None-Match
// Returns 304 with updated metadata if not modified
if (response.statusCode == 304) {
final json = jsonDecode(response.body);
final newMetadata = CacheMetadata.fromJson(json['cacheMetadata']);

// Update cache with new metadata (resets freshness)
await cache.put(
key: cacheKey,
data: cached.data,
metadata: newMetadata,
);

return cached.data;
}

// Full response
return _fetchAndCache(endpoint, params);
}
```

---

## API Design Summary

### What You Get

✅ **HTTP Caching Semantics** without HTTP headers
✅ **Age Calculation** from cache library
✅ **Freshness Determination** from cache library
✅ **Validation Support** (ETag, Last-Modified)
✅ **304 Not Modified** logic
✅ **Stale-while-revalidate** patterns
✅ **Two-tier storage** (L1 memory + L2 disk)
✅ **Eviction strategies** (LRU, LFU, TTL)

### What You Build

📦 **ManualCacheAPI** - Wrapper for manual cache operations
📦 **CacheMetadata** - Data model for body-embedded metadata
📦 **CacheableRepository** - Base class for cached repositories
📦 **Concrete Repositories** - Per-domain implementations

---

## Backend Response Contract

### Minimal Response

```json
{
  "data": {
    /* your existing data */
  },
  "cacheMetadata": {
    "cacheControl": "max-age=300"
  }
}
```

### Full Response

```json
{
  "data": {
    /* your existing data */
  },
  "cacheMetadata": {
    "cacheControl": "max-age=300, must-revalidate",
    "etag": "\"abc123\"",
    "lastModified": "2024-01-15T12:00:00Z",
    "vary": "Accept-Language",
    "date": "2024-01-15T12:05:00Z"
  }
}
```

### Component-Level Response

```json
{
  "data": {
    "vendor": {
      "name": "Pizza Place",
      "isOpen": true
    }
  },
  "cacheMetadata": {
    "components": {
      "$.vendor.name": {
        "cacheControl": "max-age=86400"
      },
      "$.vendor.isOpen": {
        "cacheControl": "max-age=30"
      }
    }
  }
}
```

---

## Validation Flow (304 Not Modified)

### Request 1: Initial Fetch

```
Client → Backend: GET /vendors/123
Backend → Client: 200 OK
{
  "data": {...},
  "cacheMetadata": {
    "cacheControl": "max-age=300",
    "etag": "\"v1\""
  }
}

Cache: Store with etag="v1"
```

### Request 2: Revalidation (after 5 minutes)

```
Cache: Stale, has etag="v1"
Client → Backend: GET /vendors/123
                  If-None-Match: "v1"

Backend: Checks ETag, data unchanged
Backend → Client: 304 Not Modified
{
  "cacheMetadata": {
    "cacheControl": "max-age=300",
    "etag": "\"v1\""
  }
}

Cache: Update metadata (reset age to 0)
Return: Cached data from before
```

### Request 3: Data Changed

```
Client → Backend: GET /vendors/123
                  If-None-Match: "v1"

Backend: Data changed
Backend → Client: 200 OK
{
  "data": {...new data...},
  "cacheMetadata": {
    "cacheControl": "max-age=300",
    "etag": "\"v2\""
  }
}

Cache: Replace old data with new
```

---

## Migration Strategy

### Phase 1: Pilot (Week 1-2)

- Add `cacheMetadata` to 1-2 endpoints
- Test with new client
- Monitor metrics

### Phase 2: Gradual Rollout (Week 3-8)

- Add to 5-10 endpoints per week
- Monitor cache hit rates
- Tune TTL values based on data

### Phase 3: Full Coverage (Week 9-12)

- All endpoints have `cacheMetadata`
- Old clients still work (ignore metadata)
- New clients fully cached

---

## Testing Strategy

### Unit Tests

```dart
test
('Manual cache stores and retrieves data
'
, () async {
final cache = HttpCache();
final manualCache = ManualCacheAPI(cache);

await manualCache.put(
key: 'vendor_123',
data: {'name': 'Pizza Place'},
metadata: CacheMetadata(cacheControl: 'max-age=300'),
);

final cached = await manualCache.get('vendor_123');
expect(cached?.isFresh, true);
expect(cached?.data['name'], 'Pizza Place');
});
```

### Integration Tests

```dart
test
('Repository caches based on metadata
'
, () async {
final mockHttp = MockHttpClient();
when(mockHttp.get(any)).thenAnswer((_) async => http.Response(
jsonEncode({
'data': {'vendor': {'name': 'Test'}},
'cacheMetadata': {'cacheControl': 'max-age=300'},
}),
200,
));

final repo = VendorRepository(
httpClient: mockHttp,
cache: manualCache,
);

final vendor1 = await repo.getVendor('123');
final vendor2 = await repo.getVendor('123');

// Second call should use cache
verify(mockHttp.get(any)).called(1); // Only 1 HTTP call
});
```

---

## Performance Considerations

### Serialization Overhead

**Problem**: Manually serializing/deserializing data
**Solution**: Use efficient JSON serialization (json_serializable)

```dart
// Generate code for efficient serialization
@JsonSerializable()
class Vendor {
  final String name;
  final bool isOpen;

  factory Vendor.fromJson(Map<String, dynamic> json) =>
      _$VendorFromJson(json);

  Map<String, dynamic> toJson() => _$VendorToJson(this);
}
```

### Cache Key Efficiency

**Problem**: String-based keys can be large
**Solution**: Hash keys for consistent length

```dart
String generateCacheKey(String endpoint, Map<String, dynamic>? params) {
  final keyString = '$endpoint${params?.toString() ?? ''}';
  return sha256.convert(utf8.encode(keyString)).toString();
}
```

---

## Advantages of This Approach

✅ **Backward Compatible** - Old clients ignore `cacheMetadata`
✅ **No API Redesign** - Just add new field to existing responses
✅ **Standard HTTP Semantics** - Reuse all caching logic from library
✅ **Component-Level Caching** - Can cache parts of response differently
✅ **Gradual Migration** - Add caching endpoint by endpoint
✅ **No Breaking Changes** - Purely additive

---

## Limitations

⚠️ **Manual Integration** - Not automatic like HTTP headers
⚠️ **More Code** - Need repository layer
⚠️ **Response Size** - Metadata adds bytes to response
⚠️ **Validation Complexity** - 304 requires backend support

---

## Conclusion

**Feasibility**: ✅ **FULLY FEASIBLE**

You can absolutely use the cache API separately without HTTP by:

1. Embedding cache metadata in response body
2. Manually calling `cache.put()` / `cache.get()`
3. Leveraging all HTTP caching semantics (age, freshness, validation)
4. Building repository layer for convenience

**Effort**: 2-3 weeks for full implementation
**Risk**: Low (backward compatible, gradual rollout)
**Benefit**: HTTP caching without changing API design

The library's internal logic for age calculation, freshness determination, and validation can all be
reused even when metadata comes from the response body instead of HTTP headers.
