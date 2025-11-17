# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter HTTP Cache is a comprehensive HTTP caching library that implements browser-style HTTP caching with full Cache-Control directive support, validation/revalidation, freshness calculation, and intelligent cache eviction strategies. The library is designed to work both with standard HTTP headers and with body-embedded cache metadata for backends that cannot be modified.

## Development Commands

### Testing
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run tests in a specific directory (when tests exist)
flutter test test/path/to/test_file.dart
```

### Building
```bash
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Run example app
cd example
flutter run
```

### Code Generation
The project uses `json_serializable` for efficient serialization (mentioned in README roadmap). When adding new models:
```bash
flutter pub run build_runner build
```

## Architecture

### Layered Design

The codebase follows clean architecture with three distinct layers:

**1. API Layer** (`lib/src/api/`)
- **Purpose**: Public interfaces and HTTP client integration
- **Key Components**:
  - `HttpCache`: Main cache orchestrator that coordinates all caching operations
  - `CacheConfig`: Configuration options for cache behavior
  - `CachedHttpClient`: HTTP client wrapper for transparent caching
  - `HttpCacheInterceptor`: Request/response interceptor that handles cache lookup, validation, and storage
  - `HttpClientFactory`: Factory for creating HTTP clients (supports `http` package and Dio)
  - `DefaultHttpClient` & `DioHttpClient`: Concrete HTTP client implementations

**2. Domain Layer** (`lib/src/domain/`)
- **Purpose**: Framework-agnostic HTTP caching business logic
- **Service Objects** (`service/`): Stateless services implementing HTTP caching algorithms
  - `AgeCalculator`: Implements RFC age calculation (apparent age, corrected age, current age)
  - `FreshnessCalculator`: Determines if cached responses are fresh based on max-age, s-maxage, Expires
  - `HeuristicFreshnessCalculator`: Implements 10% rule for responses without explicit expiration
  - `CachePolicyDecisions`: Determines storability and reusability of responses
  - `CacheValidator`: Handles conditional requests (If-None-Match, If-Modified-Since)
  - `CacheInvalidation`: Invalidates cache on unsafe methods (POST, PUT, DELETE)
  - `CacheKeyGenerator`: Generates cache keys with Vary header support
  - `HeaderUtils`: HTTP header parsing utilities

- **Value Objects** (`valueobject/`): Immutable domain entities
  - `CacheEntry`: Represents a cached HTTP response with metadata
  - `CacheControl`: Parses and represents Cache-Control directives
  - `CachePolicy`: Enum for cache policies (standard, networkOnly, cacheFirst, etc.)
  - `CacheType`: Private vs Shared cache type
  - `EvictionStrategy`: LRU, LFU, FIFO, TTL strategies
  - `HttpCacheRequest` & `HttpCacheResponse`: Request/response wrappers

**3. Data Layer** (`lib/src/data/`)
- **Purpose**: Storage implementations with pluggable backends
- **Storage Interface**: `CacheStorage` - Abstract interface for storage backends
- **Implementations** (`impl/`):
  - `MemoryStorage`: L1 in-memory cache with configurable eviction strategies
  - `DiskStorage`: L2 SQLite-based persistent cache
  - `CombinedStorage`: Two-tier coordinator that manages L1/L2 interaction with automatic promotion

### Key Design Patterns

- **Value Objects**: All domain entities are immutable and validated
- **Strategy Pattern**: Eviction strategies are pluggable (LRU, LFU, FIFO, TTL)
- **Repository Pattern**: `CacheStorage` interface with multiple implementations
- **Interceptor Pattern**: `HttpCacheInterceptor` provides transparent caching
- **Factory Pattern**: `HttpClientFactory` creates appropriate HTTP clients

### HTTP Caching Flow

1. **Request received** → `HttpCacheInterceptor.send()`
2. **Cache lookup** → `HttpCache.get()` checks policy and freshness
3. **Cache miss or stale** → Make network request via `HttpClient`
4. **Validation** → `CacheValidator` adds conditional headers (If-None-Match, If-Modified-Since)
5. **304 response** → Update cache metadata, return cached body
6. **200 response** → `HttpCache.put()` stores new entry
7. **Invalidation** → `CacheInvalidation` clears related entries on POST/PUT/DELETE

## Manual Cache API Usage (Body-Embedded Metadata)

The library supports an advanced use case where cache metadata is embedded in response bodies instead of HTTP headers. This is critical for backends that cannot be modified.

### Expected Response Format
```json
{
  "data": { /* business data */ },
  "cacheMetadata": {
    "cacheControl": "max-age=300, must-revalidate",
    "etag": "\"abc123\"",
    "lastModified": "2024-01-15T12:00:00Z",
    "vary": "Accept-Language",
    "date": "2024-01-15T12:05:00Z"
  }
}
```

### Implementation Strategy
When implementing manual cache usage:
1. Parse response body to extract `cacheMetadata` node
2. Transform metadata into HTTP headers format
3. Call `cache.put()` manually with constructed `CacheEntry`
4. Use `cache.get()` on subsequent requests to check freshness
5. Implement validation by extracting validators (ETag, Last-Modified) and adding conditional headers

See README.md "Pivotal Roadmap for Talabat Needs" section for complete implementation guide.

## Important Concepts

### Freshness Calculation
The library implements RFC-compliant freshness calculation:
1. **Explicit expiration** (priority order): `s-maxage` → `max-age` → `Expires` header
2. **Heuristic freshness**: 10% of Last-Modified age (configurable)
3. **Age calculation**: `current_age = corrected_initial_age + resident_time`

### Cache-Control Directives
**Response directives**: `max-age`, `s-maxage`, `no-cache`, `no-store`, `must-revalidate`, `proxy-revalidate`, `public`, `private`, `no-transform`
**Request directives**: `max-age`, `max-stale`, `min-fresh`, `no-cache`, `only-if-cached`

### Validation & Revalidation
- **Strong validator**: `ETag` → generates `If-None-Match`
- **Weak validator**: `Last-Modified` → generates `If-Modified-Since`
- **304 Not Modified**: Updates cached headers, resets freshness, returns cached body

### Storage Architecture
- **L1 (Memory)**: Fast access, configurable size/entry limits, eviction strategy support
- **L2 (Disk)**: SQLite persistence, survives app restarts, larger capacity
- **Combined**: Automatic L1 promotion on access, write-through to both tiers

### Vary Header Support
The library properly handles `Vary` headers for request-specific caching:
- Different cache entries for different values of specified request headers
- `Vary: *` means uncacheable

## Code Style & Conventions

- Use immutable value objects for domain entities
- All services should be stateless; state belongs in `CacheEntry` and storage
- HTTP header names are case-insensitive; use `HeaderUtils.getHeaderIgnoreCase()`
- All timestamps should use `DateTime.now()` for request/response times
- Cache keys are generated with `CacheKeyGenerator` to handle Vary headers
- Enable logging during development: `CacheConfig(enableLogging: true)`

## Testing Strategy

When writing tests:
- Unit test domain services independently (age calculation, freshness, validation logic)
- Mock `CacheStorage` when testing `HttpCache`
- Test cache policies with different `CacheControl` directives
- Verify 304 handling updates metadata correctly
- Test eviction strategies under capacity constraints
- Integration tests should verify full request/response caching flow

## Multi-Client Support

The library supports multiple HTTP clients:
- **Default**: `http` package (`HttpClientType.defaultHttp`)
- **Dio**: `dio` package (`HttpClientType.dio`)

Configure via:
```dart
CacheConfig(httpClientType: HttpClientType.dio)
```

## Common Pitfalls

- **Forgetting to call `cache.initialize()`**: Cache must be initialized before use
- **Not closing cache**: Always call `cache.close()` when done to release resources
- **Ignoring `requiresValidation`**: Check this flag before serving cached responses
- **Incorrect age calculation**: Use `AgeCalculator` service, don't compute manually
- **Missing Vary headers**: Cache key generation depends on Vary; test with varied headers
- **Stale responses in `must-revalidate` mode**: Policy decisions prevent serving stale when required

## File Organization

```
lib/
├── flutter_http_cache.dart          # Public exports
└── src/
    ├── api/                          # Public interfaces
    ├── domain/
    │   ├── service/                  # Business logic services
    │   ├── valueobject/              # Immutable domain entities
    │   └── entity/                   # Domain entities
    └── data/
        ├── storage.dart              # Storage interface
        └── impl/                     # Storage implementations
```

When adding new features:
- HTTP client support → Add to `api/` and update factory
- Caching algorithm → Add service to `domain/service/`
- Storage backend → Implement `CacheStorage` in `data/impl/`
- Configuration option → Add to `CacheConfig` in `api/cache_config.dart`
