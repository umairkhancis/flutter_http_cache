# AGENTS.md

This file provides guidance to AGENTS when working with code in this repository.

## Project Overview

This is a comprehensive HTTP caching library for Flutter applications that implements browser-style HTTP caching with full HTTP standards compliance. The library provides both automatic caching through HTTP interceptors and manual cache API for custom integration scenarios (e.g., when cache metadata comes from response body instead of headers).

**Key Features:**
- HTTP caching standard compliant implementation
- Two-tier storage (memory L1 + disk L2)
- Support for all Cache-Control directives
- Multiple HTTP client support (standard http package and Dio)
- Configurable cache policies and eviction strategies
- Manual cache API for non-HTTP use cases

## Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Clean and get dependencies
flutter clean && flutter pub get
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/directives/cache_control_test.dart

# Run with coverage
flutter test --coverage
```

### Code Quality
```bash
# Run linter
flutter analyze

# Format code
dart format .

# Check for outdated dependencies
flutter pub outdated
```

### Building
```bash
# Build example_a app (iOS)
cd example_a && flutter build ios

# Build example_a app (Android)
cd example_a && flutter build apk

# Run example_a app
cd example_a && flutter run
```

## Architecture

### Core Components

The library follows a clean, layered architecture with clear separation of concerns:

**API Layer (lib/src/api/)**

**HttpCache (cache.dart)** - Main cache orchestrator
- Core cache interface for both automatic and manual use
- Must be initialized before use (`await cache.initialize()`)
- Coordinates storage, freshness calculation, validation, and policy decisions
- Provides both high-level API (`get`, `put`) and low-level entry management

**CachedHttpClient (cached_http_client.dart)** - HTTP client with automatic caching
- Extends http.BaseClient for seamless drop-in replacement
- Delegates to HttpCacheInterceptor for cache operations
- Supports configurable cache policies per client instance

**HttpCacheInterceptor (http_cache_interceptor.dart)** - Request/response interceptor
- Intercepts HTTP requests/responses for transparent caching
- Handles cache lookup, validation, and storage automatically
- Implements stale-while-revalidate and stale-on-error patterns
- Uses pluggable HttpClient implementations (http or Dio)

**CacheConfig (cache_config.dart)** - Configuration management
- Centralized configuration for cache behavior
- Storage limits (memory/disk size and entry counts)
- Cache type (private/shared), eviction strategy
- Heuristic freshness settings
- HTTP client selection (useDio flag)

**HttpClient Abstraction (http_client.dart, default_http_client.dart, dio_http_client.dart)**
- Abstract HttpClient interface for pluggable HTTP implementations
- DefaultHttpClient wraps standard http package
- DioHttpClient wraps Dio package
- HttpClientFactory creates appropriate implementation based on config

**Data Layer (lib/src/data/)**

**CacheStorage (storage.dart)** - Storage interface
- Abstract interface for all storage implementations
- Methods: get, put, delete, clear, clearExpired, getStats, initialize

**Two-Tier Storage Implementation:**
- **CombinedStorage** (impl/combined_storage.dart): Coordinates L1 (memory) and L2 (disk) caches
- **MemoryStorage** (impl/memory_storage.dart): Fast in-memory LRU/LFU/FIFO cache (L1)
- **DiskStorage** (impl/disk_storage.dart): SQLite-backed persistent cache (L2)
- **Promotion pattern**: L2 hits automatically promoted to L1 for faster subsequent access

**Domain Layer (lib/src/domain/)**

**Domain Services (service/)** - HTTP caching business logic
- **CachePolicyDecisions** (cache_policy.dart): Determines storability and reusability based on RFC compliance
- **FreshnessCalculator** (freshness.dart): Calculates freshness lifetime from headers
- **AgeCalculator** (age_calculator.dart): Implements HTTP age calculation algorithm
- **HeuristicFreshnessCalculator** (heuristic.dart): 10% of Last-Modified age when no explicit expiration (configurable)
- **CacheValidator** (validator.dart): Generates conditional request headers (If-None-Match, If-Modified-Since)
- **CacheInvalidation** (invalidation.dart): Invalidates cache on unsafe methods (POST, PUT, DELETE)
- **CacheKeyGenerator** (cache_key_generator.dart): Generates cache keys with Vary header support
- **HeaderUtils** (header_utils.dart): HTTP header parsing, formatting, and manipulation utilities

**Value Objects (valueobject/)** - Immutable domain entities
- **CacheControl** (cache_control.dart): Parses and represents Cache-Control directives
- **CacheEntry** (cache_entry.dart): Immutable cached response with metadata
- **CachePolicy** (cache_policy.dart): Enum for cache behavior (standard, networkOnly, cacheFirst, cacheOnly, networkFirst)
- **CacheType** (cache_type.dart): Private vs shared cache distinction
- **EvictionStrategy** (eviction_strategy.dart): LRU, LFU, FIFO, TTL strategies
- **HttpCacheRequest** (http_cache_request.dart): Request representation for cache operations
- **HttpCacheResponse** (http_cache_response.dart): Response representation for cache operations

### Key Design Patterns

**Layered Architecture**
- **API Layer**: Public interfaces (HttpCache, CachedHttpClient, CacheConfig)
- **Domain Layer**: Business logic and HTTP caching semantics (completely framework-agnostic)
- **Data Layer**: Storage implementations with pluggable backends

**Value Objects Pattern**
- Immutable domain entities (CacheEntry, CacheControl)
- Self-validating and encapsulate domain logic
- Enable type-safe cache operations

**Strategy Pattern**
- Pluggable eviction strategies: LRU (recommended), LFU, FIFO, TTL
- Pluggable HTTP client implementations: http package or Dio
- Customizable storage backends via CacheStorage interface

**Repository Pattern**
- CacheStorage interface abstracts storage concerns
- Multiple implementations: MemoryStorage, DiskStorage, CombinedStorage
- Easy to add custom storage backends (Redis, Hive, etc.)

**Interceptor Pattern**
- HttpCacheInterceptor provides transparent caching
- Separates caching logic from HTTP client
- Supports different cache policies per request

**Cache Key Generation**
- Combines HTTP method, URI, and Vary header values
- SHA-256 hashing for consistent key length
- Handles Vary: * (uncacheable)
- Optional double-key caching for privacy (timing attack mitigation)

**Thread Safety**
- Uses `synchronized` package for concurrent access
- Per-entry locks for fine-grained concurrency
- Atomic operations on cache entries prevent race conditions

### HTTP Caching Compliance

The implementation strictly follows HTTP caching standards:
- Storing Responses in Caches
- Constructing Responses from Caches
- Freshness calculation
- Validation with conditional requests
- Invalidation on unsafe methods
- Cache-Control directive handling

## Testing Strategy

Tests focus on HTTP caching compliance:
- Cache-Control directive parsing and behavior
- Age calculation algorithm verification
- Freshness lifetime calculation
- Validation header generation
- 304 response handling

When writing tests:
- Test HTTP caching compliance edge cases
- Verify directive combinations and priorities
- Test storage tier promotion and eviction
- Mock HTTP responses with proper headers

## Common Development Patterns

### Adding New Cache-Control Directives
1. Update `CacheControl` class parsing logic
2. Add directive handling in `CachePolicyDecisions`
3. Add tests in `test/directives/cache_control_test.dart`

### Modifying Storage Behavior
- All storage implementations must implement `CacheStorage` interface
- L1/L2 coordination happens in `CombinedStorage`
- Changes to eviction logic go in respective storage classes

### Adding New Cache Policies
- Policy decisions are centralized in `CachePolicyDecisions`
- New policies should align with HTTP caching semantics
- Update `CachePolicy` enum in `lib/src/domain/valueobject/cache_policy.dart`

### Adding Support for New HTTP Clients
1. Create new class implementing `HttpClient` interface (lib/src/api/http_client.dart)
2. Implement `send(http.Request)` method and `close()` method
3. Update `HttpClientFactory` to create new implementation
4. Add configuration flag in `CacheConfig` if needed

## Important Implementation Notes

**Age Calculation**
- Follows HTTP caching age calculation algorithm precisely
- Accounts for apparent_age, corrected_age_value, and resident_time
- Critical for proper freshness determination

**Validation Flow**
1. Check if response is fresh
2. If stale, check if validation required (must-revalidate, no-cache)
3. Generate If-None-Match/If-Modified-Since headers
4. On 304, update headers and reset freshness
5. On other responses, replace cache entry

**Storage Initialization**
- `DiskStorage` requires async initialization for SQLite setup
- `CombinedStorage` calls both storage initializers
- Always call `await cache.initialize()` before use

**Request/Response Timing**
- `requestTime` and `responseTime` are critical for age calculation
- Must be captured accurately for proper caching behavior
- Used in freshness lifetime and validation decisions

## Dependencies

Key external dependencies:
- `http: ^1.1.0` - Standard HTTP client foundation
- `dio: ^5.3.3` - Alternative HTTP client (optional)
- `sqflite: ^2.3.0` - SQLite for persistent disk storage
- `synchronized: ^3.1.0` - Thread-safe operations and locks
- `crypto: ^3.0.3` - SHA-256 hashing for cache keys
- `path: ^1.8.3` - Path manipulation utilities
- `path_provider: ^2.1.1` - Default database location discovery
- `meta: ^1.9.1` - Annotations for immutability and required parameters

Dev dependencies:
- `flutter_test` - Flutter testing framework
- `test: ^1.24.0` - Dart testing utilities
- `mocktail: ^1.0.0` - Mocking library for tests
- `flutter_lints: ^3.0.0` - Linting rules

## Recent Changes (as of November 2024)

### Major Updates
1. **Decoupled Architecture** (Commit: 260da10)
   - Separated CachedHttpClient API from core Cache API
   - Enabled independent use of HttpCache for manual caching scenarios
   - Better exemplification of both automatic and manual usage patterns

2. **Multi-Client Support** (Commit: 84827c4)
   - Added support for multiple HTTP client implementations
   - Introduced HttpClient abstraction layer
   - Dio integration for enhanced HTTP capabilities
   - Factory pattern for client creation

3. **Enhanced Documentation**
   - Added comprehensive docs for manual cache API usage
   - Documented roadmap for Talabat-specific needs (body-embedded cache metadata)
   - HTTP caching flow documentation (HTTP_CACHE_FLOW.md)

### Current State
- Version: 0.1.0
- Branch: develop (working branch)
- Main branch: main
- Production-ready with comprehensive HTTP caching implementation
- Supports both automatic (interceptor-based) and manual caching workflows

## Project Structure

```
lib/
├── flutter_http_cache.dart          # Public API exports
└── src/
    ├── api/                          # Application layer
    │   ├── cache.dart                  # HttpCache - main orchestrator
    │   ├── cache_config.dart           # Configuration
    │   ├── cached_http_client.dart     # Automatic caching HTTP client
    │   ├── http_cache_interceptor.dart # Request/response interceptor
    │   ├── http_client.dart            # Abstract HTTP client
    │   ├── default_http_client.dart    # Standard http implementation
    │   ├── dio_http_client.dart        # Dio implementation
    │   └── http_client_factory.dart    # Client factory
    │
    ├── domain/                       # Domain layer (framework-agnostic)
    │   ├── service/                    # Domain services
    │   │   ├── age_calculator.dart       # Age calculation
    │   │   ├── cache_key_generator.dart  # Key generation with Vary
    │   │   ├── cache_policy.dart         # Storability/reusability decisions
    │   │   ├── freshness.dart            # Freshness calculation
    │   │   ├── header_utils.dart         # Header utilities
    │   │   ├── heuristic.dart            # Heuristic freshness
    │   │   ├── invalidation.dart         # Cache invalidation
    │   │   └── validator.dart            # Conditional requests
    │   │
    │   └── valueobject/                # Value objects
    │       ├── cache_control.dart        # Cache-Control parsing
    │       ├── cache_entry.dart          # Cached response entity
    │       ├── cache_policy.dart         # Policy enum
    │       ├── cache_type.dart           # Private/Shared
    │       ├── eviction_strategy.dart    # Eviction strategies
    │       ├── http_cache_request.dart   # Request representation
    │       └── http_cache_response.dart  # Response representation
    │
    └── data/                         # Data layer
        ├── storage.dart                  # Storage interface
        └── impl/                         # Implementations
            ├── combined_storage.dart       # L1/L2 coordinator
            ├── memory_storage.dart         # L1 in-memory
            └── disk_storage.dart           # L2 SQLite
```

## Usage Examples

### Automatic Caching (Standard HTTP Headers)

Initialize cache and create cached HTTP client:

    final cache = HttpCache(
      config: const CacheConfig(
        maxMemorySize: 10 * 1024 * 1024,  // 10MB
        maxDiskSize: 50 * 1024 * 1024,    // 50MB
        useDio: false,                     // Use standard http
      ),
    );
    await cache.initialize();

    final client = CachedHttpClient(
      cache: cache,
      defaultCachePolicy: CachePolicy.standard,
    );

    // Make requests - automatically cached based on response headers
    final response = await client.get(Uri.parse('https://api.example.com/data'));
    print(response.headers['x-cache']); // HIT, MISS, or HIT-STALE

### Manual Caching (Custom Metadata)

For scenarios where cache metadata comes from response body instead of HTTP headers:

    // Use HttpCache directly
    await cache.put(
      method: 'GET',
      uri: uri,
      statusCode: 200,
      requestHeaders: {},
      responseHeaders: {
        'cache-control': 'max-age=300',
        'etag': '"abc123"',
      },
      body: responseBody,
      requestTime: requestTime,
      responseTime: responseTime,
    );

    // Retrieve from cache
    final cached = await cache.get(
      method: 'GET',
      uri: uri,
      requestHeaders: {},
      policy: CachePolicy.standard,
    );

    if (cached != null && !cached.requiresValidation) {
      // Use cached response
      print('Age: ${cached.age}s, Fresh: ${!cached.isStale}');
    }

## Future Roadmap

See README.md section "Pivotal Roadmap for Talabat Needs" for detailed plan on:
- Manual cache API for body-embedded metadata
- Backend response contract with `cacheMetadata` field
- Repository pattern for custom integration
- Component-level caching support
- Migration strategy for gradual adoption
