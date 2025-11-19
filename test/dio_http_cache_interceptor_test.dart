import 'package:dio/dio.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpCache extends Mock implements HttpCache {}

class MockCacheConfig extends Mock implements CacheConfig {}

class FakeUri extends Fake implements Uri {}

class FakeRequestOptions extends Fake implements RequestOptions {}

class FakeRequestInterceptorHandler extends Fake
    implements RequestInterceptorHandler {}

class FakeResponseInterceptorHandler extends Fake
    implements ResponseInterceptorHandler {}

class FakeErrorInterceptorHandler extends Fake implements ErrorInterceptorHandler {}

class FakeCacheEntry extends Fake implements CacheEntry {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(CachePolicy.standard);
    registerFallbackValue(FakeCacheEntry());
  });

  group('DioHttpCacheInterceptor', () {
    late HttpCache mockCache;
    late DioHttpCacheInterceptor interceptor;
    late CacheConfig config;

    setUp(() {
      mockCache = MockHttpCache();
      config = CacheConfig(enableLogging: false);

      when(() => mockCache.config).thenReturn(config);
      when(() => mockCache.initialize()).thenAnswer((_) async {});

      interceptor = DioHttpCacheInterceptor(mockCache);
    });

    group('onRequest', () {
      test('cache hit with fresh response should resolve immediately', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        final cachedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: [1, 2, 3],
          responseTime: DateTime.now(),
          requestTime: DateTime.now().subtract(const Duration(seconds: 1)),
          varyHeaders: {},
        );

        final cachedResponse = CachedResponse(
          entry: cachedEntry,
          requiresValidation: false,
          isStale: false,
          age: 10,
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => cachedResponse);

        Response? resolvedResponse;
        final handler = _MockRequestInterceptorHandler(
          onResolve: (response) => resolvedResponse = response,
        );

        // Act - wait for async operations to complete
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero); // Let async operations complete

        // Assert
        expect(resolvedResponse, isNotNull);
        expect(resolvedResponse!.statusCode, 200);
        // Data should be decoded based on content-type
        expect(resolvedResponse!.headers.value('x-cache'), 'HIT');
        expect(resolvedResponse!.headers.value('age'), '10');

        verify(() => mockCache.get(
              method: 'GET',
              uri: uri,
              requestHeaders: any(named: 'requestHeaders'),
              policy: CachePolicy.standard,
            )).called(1);
      });

      test('cache hit with stale response should include warning', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        final cachedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: [1, 2, 3],
          responseTime: DateTime.now().subtract(const Duration(hours: 2)),
          requestTime: DateTime.now().subtract(const Duration(hours: 2, seconds: 1)),
          varyHeaders: {},
        );

        final cachedResponse = CachedResponse(
          entry: cachedEntry,
          requiresValidation: false,
          isStale: true,
          age: 7200,
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => cachedResponse);

        Response? resolvedResponse;
        final handler = _MockRequestInterceptorHandler(
          onResolve: (response) => resolvedResponse = response,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(resolvedResponse, isNotNull);
        expect(resolvedResponse!.headers.value('x-cache'), 'HIT-STALE');
        expect(resolvedResponse!.headers.value('warning'), isNotNull);
      });

      test('cache miss should continue with request', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => null);

        RequestOptions? nextOptions;
        final handler = _MockRequestInterceptorHandler(
          onNext: (opts) => nextOptions = opts,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(nextOptions, isNotNull);
        expect(nextOptions!.extra.containsKey('_requestTime'), true);
      });

      test('requires validation should add conditional headers', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        final cachedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {
            'content-type': 'application/json',
            'etag': '"abc123"',
          },
          body: [1, 2, 3],
          responseTime: DateTime.now().subtract(const Duration(hours: 2)),
          requestTime: DateTime.now().subtract(const Duration(hours: 2, seconds: 1)),
          varyHeaders: {},
        );

        final cachedResponse = CachedResponse(
          entry: cachedEntry,
          requiresValidation: true,
          isStale: true,
          age: 7200,
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => cachedResponse);

        when(() => mockCache.generateValidationHeaders(
              any(),
              any(),
            )).thenReturn({'if-none-match': '"abc123"'});

        RequestOptions? nextOptions;
        final handler = _MockRequestInterceptorHandler(
          onNext: (opts) => nextOptions = opts,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(nextOptions, isNotNull);
        expect(nextOptions!.headers['if-none-match'], '"abc123"');
        expect(nextOptions!.extra['_cachedEntry'], cachedEntry);
      });

      test('cacheOnly policy with cache miss should reject with 504', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
          extra: {'cachePolicy': CachePolicy.cacheOnly},
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => null);

        DioException? rejectedException;
        final handler = _MockRequestInterceptorHandler(
          onReject: (error) => rejectedException = error,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(rejectedException, isNotNull);
        expect(rejectedException!.response?.statusCode, 504);
        expect(rejectedException!.message, 'Cache Miss - only-if-cached');
      });

      test('networkOnly policy should skip cache lookup', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
          extra: {'cachePolicy': CachePolicy.networkOnly},
        );

        RequestOptions? nextOptions;
        final handler = _MockRequestInterceptorHandler(
          onNext: (opts) => nextOptions = opts,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onRequest(options, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(nextOptions, isNotNull);
        verifyNever(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            ));
      });
    });

    group('onResponse', () {
      test('should store response in cache', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final requestTime = DateTime.now().subtract(const Duration(seconds: 1));
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
          extra: {'_requestTime': requestTime},
        );

        final response = Response(
          requestOptions: options,
          statusCode: 200,
          data: [1, 2, 3],
          headers: Headers.fromMap({
            'content-type': ['application/json'],
            'cache-control': ['max-age=3600'],
          }),
        );

        when(() => mockCache.put(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              statusCode: any(named: 'statusCode'),
              requestHeaders: any(named: 'requestHeaders'),
              responseHeaders: any(named: 'responseHeaders'),
              body: any(named: 'body'),
              requestTime: any(named: 'requestTime'),
              responseTime: any(named: 'responseTime'),
            )).thenAnswer((_) async => true);

        Response? nextResponse;
        final handler = _MockResponseInterceptorHandler(
          onNext: (resp) => nextResponse = resp,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onResponse(response, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(nextResponse, isNotNull);
        verify(() => mockCache.put(
              method: 'GET',
              uri: uri,
              statusCode: 200,
              requestHeaders: any(named: 'requestHeaders'),
              responseHeaders: any(named: 'responseHeaders'),
              body: any(named: 'body'),
              requestTime: requestTime,
              responseTime: any(named: 'responseTime'),
            )).called(1);
      });

      test('304 response should update cached entry', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final requestTime = DateTime.now().subtract(const Duration(seconds: 1));

        // Use realistic JSON data
        final jsonBody = '{"id":1,"title":"test"}'.codeUnits;

        final cachedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {
            'content-type': 'application/json',
            'etag': '"abc123"',
          },
          body: jsonBody,
          responseTime: DateTime.now().subtract(const Duration(hours: 1)),
          requestTime: DateTime.now().subtract(const Duration(hours: 1, seconds: 1)),
          varyHeaders: {},
        );

        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
          extra: {
            '_requestTime': requestTime,
            '_cachedEntry': cachedEntry,
          },
        );

        final response = Response(
          requestOptions: options,
          statusCode: 304,
          headers: Headers.fromMap({
            'etag': ['"abc123"'],
            'cache-control': ['max-age=3600'],
          }),
        );

        final updatedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {
            'content-type': 'application/json',
            'etag': '"abc123"',
            'cache-control': 'max-age=3600',
          },
          body: jsonBody,
          responseTime: DateTime.now(),
          requestTime: requestTime,
          varyHeaders: {},
        );

        when(() => mockCache.updateFrom304(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              response304Headers: any(named: 'response304Headers'),
              validationRequestTime: any(named: 'validationRequestTime'),
              validationResponseTime: any(named: 'validationResponseTime'),
            )).thenAnswer((_) async => updatedEntry);

        Response? resolvedResponse;
        final handler = _MockResponseInterceptorHandler(
          onResolve: (resp) => resolvedResponse = resp,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onResponse(response, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(resolvedResponse, isNotNull);
        expect(resolvedResponse!.statusCode, 200);
        // Data should be decoded JSON
        expect(resolvedResponse!.data, isA<Map>());
        expect(resolvedResponse!.data['id'], 1);
        expect(resolvedResponse!.data['title'], 'test');
        verify(() => mockCache.updateFrom304(
              method: 'GET',
              uri: uri,
              requestHeaders: any(named: 'requestHeaders'),
              response304Headers: any(named: 'response304Headers'),
              validationRequestTime: requestTime,
              validationResponseTime: any(named: 'validationResponseTime'),
            )).called(1);
      });
    });

    group('onError', () {
      test('should serve stale cache on network error when configured', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        final dioError = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );

        // Use realistic JSON data
        final jsonBody = '{"id":1,"title":"test"}'.codeUnits;

        final cachedEntry = CacheEntry(
          method: 'GET',
          uri: uri,
          statusCode: 200,
          headers: {'content-type': 'application/json'},
          body: jsonBody,
          responseTime: DateTime.now().subtract(const Duration(hours: 2)),
          requestTime: DateTime.now().subtract(const Duration(hours: 2, seconds: 1)),
          varyHeaders: {},
        );

        final cachedResponse = CachedResponse(
          entry: cachedEntry,
          requiresValidation: false,
          isStale: true,
          age: 7200,
        );

        final configWithStaleOnError = CacheConfig(
          enableLogging: false,
          serveStaleOnError: true,
        );
        when(() => mockCache.config).thenReturn(configWithStaleOnError);

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => cachedResponse);

        Response? resolvedResponse;
        final handler = _MockErrorInterceptorHandler(
          onResolve: (resp) => resolvedResponse = resp,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onError(dioError, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(resolvedResponse, isNotNull);
        expect(resolvedResponse!.statusCode, 200);
        // Data should be decoded JSON
        expect(resolvedResponse!.data, isA<Map>());
        expect(resolvedResponse!.data['id'], 1);
        expect(resolvedResponse!.data['title'], 'test');
        expect(resolvedResponse!.headers.value('x-cache'), 'HIT-STALE');
      });

      test('should continue with error when no stale cache available', () async {
        // Arrange
        final uri = Uri.parse('https://api.example.com/data');
        final options = RequestOptions(
          path: uri.toString(),
          method: 'GET',
        );

        final dioError = DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timeout',
        );

        when(() => mockCache.get(
              method: any(named: 'method'),
              uri: any(named: 'uri'),
              requestHeaders: any(named: 'requestHeaders'),
              policy: any(named: 'policy'),
            )).thenAnswer((_) async => null);

        DioException? nextError;
        final handler = _MockErrorInterceptorHandler(
          onNext: (err) => nextError = err,
        );

        // Act - wait for async operations
        await Future.microtask(() => interceptor.onError(dioError, handler));
        await Future.delayed(Duration.zero);

        // Assert
        expect(nextError, isNotNull);
        expect(nextError!.message, 'Connection timeout');
      });
    });
  });
}

// Mock handler implementations for testing
class _MockRequestInterceptorHandler implements RequestInterceptorHandler {
  final void Function(Response)? onResolve;
  final void Function(DioException)? onReject;
  final void Function(RequestOptions)? onNext;

  _MockRequestInterceptorHandler({
    this.onResolve,
    this.onReject,
    this.onNext,
  });

  @override
  void resolve(Response response, [bool callFollowingResponseInterceptor = false]) {
    onResolve?.call(response);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    onReject?.call(error);
  }

  @override
  void next(RequestOptions requestOptions) {
    onNext?.call(requestOptions);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockResponseInterceptorHandler implements ResponseInterceptorHandler {
  final void Function(Response)? onResolve;
  final void Function(DioException)? onReject;
  final void Function(Response)? onNext;

  _MockResponseInterceptorHandler({
    this.onResolve,
    this.onReject,
    this.onNext,
  });

  @override
  void resolve(Response response, [bool callFollowingResponseInterceptor = false]) {
    onResolve?.call(response);
  }

  @override
  void reject(DioException error, [bool callFollowingErrorInterceptor = false]) {
    onReject?.call(error);
  }

  @override
  void next(Response response) {
    onNext?.call(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockErrorInterceptorHandler implements ErrorInterceptorHandler {
  final void Function(Response)? onResolve;
  final void Function(DioException)? onReject;
  final void Function(DioException)? onNext;

  _MockErrorInterceptorHandler({
    this.onResolve,
    this.onReject,
    this.onNext,
  });

  @override
  void resolve(Response response) {
    onResolve?.call(response);
  }

  @override
  void reject(DioException error) {
    onReject?.call(error);
  }

  @override
  void next(DioException err) {
    onNext?.call(err);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
