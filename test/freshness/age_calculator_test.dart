import 'package:flutter_http_cache/src/domain/service/age_calculator.dart';
import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgeCalculator', () {
    test('calculates age correctly with no Age header', () {
      final now = DateTime.now();
      final requestTime = now.subtract(const Duration(seconds: 10));
      final responseTime = now.subtract(const Duration(seconds: 5));

      final entry = CacheEntry(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/data'),
        statusCode: 200,
        headers: {
          'date': responseTime.toUtc().toIso8601String(),
        },
        body: const [],
        requestTime: requestTime,
        responseTime: responseTime,
      );

      final age = AgeCalculator.calculateAge(entry, now: now);

      // Age calculation per HTTP caching standard:
      // response_delay = responseTime - requestTime = 5 seconds
      // resident_time = now - responseTime = 5 seconds
      // current_age = response_delay + resident_time = 10 seconds
      expect(age.inSeconds, greaterThanOrEqualTo(9));
      expect(age.inSeconds, lessThanOrEqualTo(11));
    });

    test('calculates age with Age header', () {
      final now = DateTime.now();
      final requestTime = now.subtract(const Duration(seconds: 100));
      final responseTime = now.subtract(const Duration(seconds: 95));

      final entry = CacheEntry(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/data'),
        statusCode: 200,
        headers: {
          'date': responseTime.toUtc().toIso8601String(),
          'age': '50', // Response was already 50 seconds old when received
        },
        body: const [],
        requestTime: requestTime,
        responseTime: responseTime,
      );

      final age = AgeCalculator.calculateAge(entry, now: now);

      // Age should be approximately 50 (Age header) + 95 (resident time) + 5 (response delay)
      // Total: ~150 seconds
      expect(age.inSeconds, greaterThan(140));
      expect(age.inSeconds, lessThan(160));
    });

    test('calculates apparent age when Date is earlier than response time', () {
      final now = DateTime.now();
      final requestTime = now.subtract(const Duration(seconds: 10));
      final responseTime = now.subtract(const Duration(seconds: 5));
      final dateTime =
          now.subtract(const Duration(seconds: 100)); // Very old Date header

      final entry = CacheEntry(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/data'),
        statusCode: 200,
        headers: {
          'date': dateTime.toUtc().toIso8601String(),
        },
        body: const [],
        requestTime: requestTime,
        responseTime: responseTime,
      );

      final age = AgeCalculator.calculateAge(entry, now: now);

      // Apparent age should dominate: response_time - date_time = ~95 seconds
      // Plus resident time: ~5 seconds
      // Total: ~100 seconds
      expect(age.inSeconds, greaterThan(95));
      expect(age.inSeconds, lessThan(105));
    });

    test('calculates age in seconds', () {
      final now = DateTime.now();
      final requestTime = now.subtract(const Duration(seconds: 10));
      final responseTime = now.subtract(const Duration(seconds: 5));

      final entry = CacheEntry(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/data'),
        statusCode: 200,
        headers: {
          'date': responseTime.toUtc().toIso8601String(),
        },
        body: const [],
        requestTime: requestTime,
        responseTime: responseTime,
      );

      final ageSeconds = AgeCalculator.calculateAgeInSeconds(entry, now: now);

      // Age calculation per HTTP caching standard:
      // response_delay = responseTime - requestTime = 5 seconds
      // resident_time = now - responseTime = 5 seconds
      // current_age = response_delay + resident_time = 10 seconds
      expect(ageSeconds, greaterThanOrEqualTo(9));
      expect(ageSeconds, lessThanOrEqualTo(11));
    });

    test('checks if age exceeds maximum', () {
      final now = DateTime.now();
      final requestTime = now.subtract(const Duration(seconds: 100));
      final responseTime = now.subtract(const Duration(seconds: 95));

      final entry = CacheEntry(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/data'),
        statusCode: 200,
        headers: {
          'date': responseTime.toUtc().toIso8601String(),
        },
        body: const [],
        requestTime: requestTime,
        responseTime: responseTime,
      );

      final exceeded = AgeCalculator.isAgeExceeded(
        entry,
        const Duration(seconds: 50),
        now: now,
      );

      expect(exceeded, true);

      final notExceeded = AgeCalculator.isAgeExceeded(
        entry,
        const Duration(seconds: 200),
        now: now,
      );

      expect(notExceeded, false);
    });
  });
}
