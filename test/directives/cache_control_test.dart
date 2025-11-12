import 'package:flutter_http_cache/src/domain/valueobject/cache_control.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CacheControl Parser', () {
    test('parses max-age directive', () {
      final cc = CacheControl.parse('max-age=3600');
      expect(cc.maxAge, 3600);
    });

    test('parses multiple directives', () {
      final cc =
          CacheControl.parse('max-age=3600, must-revalidate, no-transform');
      expect(cc.maxAge, 3600);
      expect(cc.mustRevalidate, true);
      expect(cc.noTransform, true);
    });

    test('parses no-cache with fields', () {
      final cc = CacheControl.parse('no-cache="Set-Cookie, Authorization"');
      expect(cc.noCache, true);
      expect(cc.noCacheFields, ['Set-Cookie', 'Authorization']);
    });

    test('parses private with fields', () {
      final cc = CacheControl.parse('private="Set-Cookie"');
      expect(cc.isPrivate, true);
      expect(cc.privateFields, ['Set-Cookie']);
    });

    test('parses s-maxage for shared caches', () {
      final cc = CacheControl.parse('s-maxage=7200, max-age=3600');
      expect(cc.sMaxAge, 7200);
      expect(cc.maxAge, 3600);
    });

    test('parses request directives', () {
      final cc = CacheControl.parse(
        'max-age=0, max-stale=100, min-fresh=30',
        isRequest: true,
      );
      expect(cc.requestMaxAge, 0);
      expect(cc.maxStale, 100);
      expect(cc.minFresh, 30);
    });

    test('parses max-stale without value', () {
      final cc = CacheControl.parse('max-stale', isRequest: true);
      expect(cc.maxStaleAny, true);
    });

    test('parses only-if-cached', () {
      final cc = CacheControl.parse('only-if-cached', isRequest: true);
      expect(cc.onlyIfCached, true);
    });

    test('parses no-store', () {
      final cc = CacheControl.parse('no-store');
      expect(cc.noStore, true);
      expect(cc.prohibitsStorage, true);
    });

    test('parses public directive', () {
      final cc = CacheControl.parse('public, max-age=3600');
      expect(cc.isPublic, true);
      expect(cc.maxAge, 3600);
    });

    test('handles extension directives', () {
      final cc = CacheControl.parse('max-age=3600, immutable');
      expect(cc.maxAge, 3600);
      expect(cc.extensions.containsKey('immutable'), true);
    });

    test('handles quoted values', () {
      final cc = CacheControl.parse('max-age="3600"');
      expect(cc.maxAge, 3600);
    });

    test('handles whitespace variations', () {
      final cc = CacheControl.parse('  max-age = 3600 ,  must-revalidate  ');
      expect(cc.maxAge, 3600);
      expect(cc.mustRevalidate, true);
    });

    test('handles empty string', () {
      final cc = CacheControl.parse('');
      expect(cc.maxAge, null);
      expect(cc.noCache, false);
    });

    test('handles null', () {
      final cc = CacheControl.parse(null);
      expect(cc.maxAge, null);
      expect(cc.noCache, false);
    });

    test('toString generates correct format', () {
      final cc = CacheControl.parse('max-age=3600, no-cache, public');
      final str = cc.toString();
      expect(str.contains('max-age=3600'), true);
      expect(str.contains('no-cache'), true);
      expect(str.contains('public'), true);
    });
  });
}
