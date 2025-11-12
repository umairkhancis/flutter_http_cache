# Manual Cache API Usage Plan
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
      method: 'MANUAL', // Pseudo method
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
  Future<T> fetch(
    String endpoint, {
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

  Future<T> _fetchAndCache(
    String endpoint,
    Map<String, dynamic>? params,
  ) async {
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

  Future<T> _revalidate(
    String endpoint,
    Map<String, dynamic>? params,
    CachedData<T> cached,
  ) async {
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
await cache.initialize();

// Create manual API
final manualCache = ManualCacheAPI(cache);

// Create repository
final vendorRepo = VendorRepository(
  httpClient: http.Client(),
  cache: manualCache,
);

// Usage
final vendor = await vendorRepo.getVendor('123');
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
        "cacheControl": "max-age=86400"  // 1 day
      },
      "$.vendor.isOpen": {
        "cacheControl": "max-age=30"  // 30 seconds
      },
      "$.vendor.menu": {
        "cacheControl": "max-age=21600"  // 6 hours
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
  "data": { /* your existing data */ },
  "cacheMetadata": {
    "cacheControl": "max-age=300"
  }
}
```

### Full Response

```json
{
  "data": { /* your existing data */ },
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
test('Manual cache stores and retrieves data', () async {
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
test('Repository caches based on metadata', () async {
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

The library's internal logic for age calculation, freshness determination, and validation can all be reused even when metadata comes from the response body instead of HTTP headers.
