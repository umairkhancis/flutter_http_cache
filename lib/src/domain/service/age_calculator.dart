import 'package:flutter_http_cache/src/domain/valueobject/cache_entry.dart';

/// Calculates the age of cached responses
class AgeCalculator {
  /// Calculates the current age of a cached response
  /// Implements the HTTP caching age calculation algorithm 
  ///
  /// ```
  /// apparent_age = max(0, response_time - date_value)
  /// response_delay = response_time - request_time
  /// corrected_age_value = age_value + response_delay
  /// corrected_initial_age = max(apparent_age, corrected_age_value)
  /// resident_time = now - response_time
  /// current_age = corrected_initial_age + resident_time
  /// ```
  static Duration calculateAge(CacheEntry entry, {DateTime? now}) {
    now ??= DateTime.now();

    // Extract values from the cache entry
    final dateValue = entry.dateHeader ?? entry.responseTime;
    final ageValue = entry.ageHeader ?? 0;
    final responseTime = entry.responseTime;
    final requestTime = entry.requestTime;

    // Step 1: Calculate apparent_age
    // This is how old the response appears to be based on the Date header
    final apparentAge = _max(
      Duration.zero,
      responseTime.difference(dateValue),
    );

    // Step 2: Calculate response_delay
    // This is how long the response took to arrive
    final responseDelay = responseTime.difference(requestTime);

    // Step 3: Calculate corrected_age_value
    // This adjusts the Age header value by the response delay
    final correctedAgeValue = Duration(seconds: ageValue) + responseDelay;

    // Step 4: Calculate corrected_initial_age
    // This is the age of the response when it was received
    final correctedInitialAge = _max(apparentAge, correctedAgeValue);

    // Step 5: Calculate resident_time
    // This is how long the response has been stored in the cache
    final residentTime = now.difference(responseTime);

    // Step 6: Calculate current_age
    // This is the total age of the response now
    final currentAge = correctedInitialAge + residentTime;

    return currentAge;
  }

  /// Helper to get the maximum of two durations
  static Duration _max(Duration a, Duration b) {
    return a > b ? a : b;
  }

  /// Calculates the age in seconds for the Age header
  static int calculateAgeInSeconds(CacheEntry entry, {DateTime? now}) {
    final age = calculateAge(entry, now: now);
    return age.inSeconds;
  }

  /// Checks if the response age exceeds a maximum age limit
  static bool isAgeExceeded(CacheEntry entry, Duration maxAge, {DateTime? now}) {
    final currentAge = calculateAge(entry, now: now);
    return currentAge > maxAge;
  }
}
