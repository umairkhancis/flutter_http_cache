# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive HTTP caching library for Flutter applications. It implements browser-style HTTP caching with support for Cache-Control directives, validation, freshness calculation, and intelligent cache eviction strategies.

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
# Build example app (iOS)
cd example && flutter build ios

# Build example app (Android)
cd example && flutter build apk

# Run example app
cd example && flutter run
```

## Architecture

### Core Components

The library follows a layered architecture implementing modern HTTP Caching semantics:

**HttpCache (lib/src/api/cache.dart)** - Main cache interface
- Orchestrates all caching operations
- Must be initialized before use (`await cache.initialize()`)
- Integrates storage, freshness, validation, and policy components

**CachedHttpClient (lib/src/api/cached_http_client.dart)** - HTTP client with caching
- Extends http.BaseClient for seamless integration
- Delegates to HttpCacheInterceptor for cache operations
- Supports configurable cache policies per client instance

**HttpCacheInterceptor (lib/src/api/http_cache_interceptor.dart)** - Core caching logic
- Intercepts HTTP requests/responses
- Handles cache lookup, validation, and storage
- Implements stale-while-revalidate and stale-on-error patterns

**Two-Tier Storage Architecture (lib/src/data/)**
- **CombinedStorage** (lib/src/data/impl/combined_storage.dart): Coordinates L1 (memory) and L2 (disk) caches
- **MemoryStorage** (lib/src/data/impl/memory_storage.dart): Fast in-memory LRU/LFU/FIFO cache (L1)
- **DiskStorage** (lib/src/data/impl/disk_storage.dart): SQLite-backed persistent cache (L2)
- **Promotion pattern**: L2 hits automatically promoted to L1

**Domain Services (lib/src/domain/service/)**
- **CachePolicyDecisions** (cache_policy.dart): Storability and reusability decisions
- **FreshnessCalculator** (freshness.dart): Freshness lifetime calculation
- **AgeCalculator** (age_calculator.dart): Current age calculation algorithm
- **HeuristicFreshnessCalculator** (heuristic.dart): 10% of Last-Modified age (configurable)
- **CacheValidator** (validator.dart): Conditional request generation
- **CacheInvalidation** (invalidation.dart): Unsafe method invalidation
- **CacheKeyGenerator** (cache_key_generator.dart): Primary and Vary-based cache key generation
- **HeaderUtils** (header_utils.dart): HTTP header parsing and manipulation utilities

**Value Objects (lib/src/domain/valueobject/)**
- **CacheControl** (cache_control.dart): Parses and represents Cache-Control directives
- **CacheEntry** (cache_entry.dart): Immutable representation of cached responses
- **CachePolicy** (cache_policy.dart): Enum for cache behavior policies (standard, networkOnly, cacheFirst, etc.)
- **CacheType** (cache_type.dart): Private vs shared cache distinction
- **EvictionStrategy** (eviction_strategy.dart): LRU, LFU, FIFO, TTL strategies

### Key Design Patterns

**Cache Key Generation (lib/src/cache/cache_key.dart)**
- Combines method, URI, and Vary header values
- Handles Vary: * (never matches)
- Double-key caching support for privacy (timing attack mitigation)

**Thread Safety**
- Uses `synchronized` package for concurrent access
- Locks ensure atomic operations on cache entries

**Eviction Strategies**
- LRU (Least Recently Used) - recommended for most cases
- LFU (Least Frequently Used)
- FIFO (First In First Out)
- TTL (Time To Live)

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
- Update `CachePolicy` enum in `lib/src/storage/storage.dart`

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
- `http` - HTTP client foundation
- `sqflite` - SQLite for disk storage
- `synchronized` - Thread-safe operations
- `crypto` - Cache key hashing
- `path_provider` - Default database location
