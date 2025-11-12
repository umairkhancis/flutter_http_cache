import 'package:meta/meta.dart';

/// Represents parsed Cache-Control directives
/// Implements Cache-Control header parsing and representation
@immutable
class CacheControl {
  // Response directives (mandatory)
  final int? maxAge;
  final bool mustRevalidate;
  final bool mustUnderstand;
  final bool noCache;
  final List<String> noCacheFields;
  final bool noStore;
  final bool noTransform;
  final bool isPrivate;
  final List<String> privateFields;
  final bool proxyRevalidate;
  final bool isPublic;
  final int? sMaxAge;

  // Request directives (advisory)
  final int? requestMaxAge;
  final int? maxStale;
  final bool maxStaleAny;
  final int? minFresh;
  final bool requestNoCache;
  final bool requestNoStore;
  final bool requestNoTransform;
  final bool onlyIfCached;

  // Extension directives
  final Map<String, String?> extensions;

  const CacheControl({
    // Response directives
    this.maxAge,
    this.mustRevalidate = false,
    this.mustUnderstand = false,
    this.noCache = false,
    this.noCacheFields = const [],
    this.noStore = false,
    this.noTransform = false,
    this.isPrivate = false,
    this.privateFields = const [],
    this.proxyRevalidate = false,
    this.isPublic = false,
    this.sMaxAge,
    // Request directives
    this.requestMaxAge,
    this.maxStale,
    this.maxStaleAny = false,
    this.minFresh,
    this.requestNoCache = false,
    this.requestNoStore = false,
    this.requestNoTransform = false,
    this.onlyIfCached = false,
    // Extensions
    this.extensions = const {},
  });

  /// Parses a Cache-Control header value into a CacheControl object
  /// Handles both request and response directives
  static CacheControl parse(String? headerValue, {bool isRequest = false}) {
    if (headerValue == null || headerValue.isEmpty) {
      return const CacheControl();
    }

    final directives = _parseDirectives(headerValue);

    // Response directives
    int? maxAge;
    bool mustRevalidate = false;
    bool mustUnderstand = false;
    bool noCache = false;
    List<String> noCacheFields = [];
    bool noStore = false;
    bool noTransform = false;
    bool isPrivate = false;
    List<String> privateFields = [];
    bool proxyRevalidate = false;
    bool isPublic = false;
    int? sMaxAge;

    // Request directives
    int? requestMaxAge;
    int? maxStale;
    bool maxStaleAny = false;
    int? minFresh;
    bool requestNoCache = false;
    bool requestNoStore = false;
    bool requestNoTransform = false;
    bool onlyIfCached = false;

    // Extensions
    final extensions = <String, String?>{};

    for (final directive in directives.entries) {
      final name = directive.key.toLowerCase();
      final value = directive.value;

      switch (name) {
        // Response directives
        case 'max-age':
          final age = _parseSeconds(value);
          if (isRequest) {
            requestMaxAge = age;
          } else {
            maxAge = age;
          }
          break;
        case 'must-revalidate':
          mustRevalidate = true;
          break;
        case 'must-understand':
          mustUnderstand = true;
          break;
        case 'no-cache':
          if (isRequest) {
            requestNoCache = true;
          } else {
            noCache = true;
            noCacheFields = _parseFieldNames(value);
          }
          break;
        case 'no-store':
          if (isRequest) {
            requestNoStore = true;
          } else {
            noStore = true;
          }
          break;
        case 'no-transform':
          if (isRequest) {
            requestNoTransform = true;
          } else {
            noTransform = true;
          }
          break;
        case 'private':
          isPrivate = true;
          privateFields = _parseFieldNames(value);
          break;
        case 'proxy-revalidate':
          proxyRevalidate = true;
          break;
        case 'public':
          isPublic = true;
          break;
        case 's-maxage':
          sMaxAge = _parseSeconds(value);
          break;

        // Request directives
        case 'max-stale':
          if (value != null) {
            maxStale = _parseSeconds(value);
          } else {
            maxStaleAny = true;
          }
          break;
        case 'min-fresh':
          minFresh = _parseSeconds(value);
          break;
        case 'only-if-cached':
          onlyIfCached = true;
          break;

        // Unknown directives are extensions
        default:
          extensions[name] = value;
          break;
      }
    }

    return CacheControl(
      maxAge: maxAge,
      mustRevalidate: mustRevalidate,
      mustUnderstand: mustUnderstand,
      noCache: noCache,
      noCacheFields: noCacheFields,
      noStore: noStore,
      noTransform: noTransform,
      isPrivate: isPrivate,
      privateFields: privateFields,
      proxyRevalidate: proxyRevalidate,
      isPublic: isPublic,
      sMaxAge: sMaxAge,
      requestMaxAge: requestMaxAge,
      maxStale: maxStale,
      maxStaleAny: maxStaleAny,
      minFresh: minFresh,
      requestNoCache: requestNoCache,
      requestNoStore: requestNoStore,
      requestNoTransform: requestNoTransform,
      onlyIfCached: onlyIfCached,
      extensions: extensions,
    );
  }

  /// Parses directives from a Cache-Control header value
  static Map<String, String?> _parseDirectives(String headerValue) {
    final directives = <String, String?>{};
    final parts = <String>[];

    // Split by comma, but respect quoted values
    var currentPart = '';
    var inQuotes = false;

    for (var i = 0; i < headerValue.length; i++) {
      final char = headerValue[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        currentPart += char;
      } else if (char == ',' && !inQuotes) {
        parts.add(currentPart);
        currentPart = '';
      } else {
        currentPart += char;
      }
    }

    if (currentPart.isNotEmpty) {
      parts.add(currentPart);
    }

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      final equalsIndex = part.indexOf('=');
      if (equalsIndex == -1) {
        // Directive without value
        directives[part] = null;
      } else {
        // Directive with value
        final name = part.substring(0, equalsIndex).trim();
        var value = part.substring(equalsIndex + 1).trim();

        // Remove quotes if present
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }

        directives[name] = value;
      }
    }

    return directives;
  }

  /// Parses a seconds value from a directive
  static int? _parseSeconds(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Parses field names from a directive value (e.g., no-cache="Set-Cookie, Authorization")
  static List<String> _parseFieldNames(String? value) {
    if (value == null) return [];
    return value.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
  }

  /// Checks if caching is prohibited by no-store
  bool get prohibitsStorage => noStore || requestNoStore;

  /// Checks if validation is required (no-cache or must-revalidate)
  bool get requiresValidation => noCache || requestNoCache || mustRevalidate;

  @override
  String toString() {
    final parts = <String>[];

    if (maxAge != null) parts.add('max-age=$maxAge');
    if (sMaxAge != null) parts.add('s-maxage=$sMaxAge');
    if (requestMaxAge != null) parts.add('max-age=$requestMaxAge');
    if (mustRevalidate) parts.add('must-revalidate');
    if (mustUnderstand) parts.add('must-understand');
    if (noCache || requestNoCache) {
      if (noCacheFields.isNotEmpty) {
        parts.add('no-cache="${noCacheFields.join(', ')}"');
      } else {
        parts.add('no-cache');
      }
    }
    if (noStore || requestNoStore) parts.add('no-store');
    if (noTransform || requestNoTransform) parts.add('no-transform');
    if (isPrivate) {
      if (privateFields.isNotEmpty) {
        parts.add('private="${privateFields.join(', ')}"');
      } else {
        parts.add('private');
      }
    }
    if (proxyRevalidate) parts.add('proxy-revalidate');
    if (isPublic) parts.add('public');
    if (maxStaleAny) {
      parts.add('max-stale');
    } else if (maxStale != null) {
      parts.add('max-stale=$maxStale');
    }
    if (minFresh != null) parts.add('min-fresh=$minFresh');
    if (onlyIfCached) parts.add('only-if-cached');

    extensions.forEach((key, value) {
      if (value != null) {
        parts.add('$key=$value');
      } else {
        parts.add(key);
      }
    });

    return parts.join(', ');
  }
}
