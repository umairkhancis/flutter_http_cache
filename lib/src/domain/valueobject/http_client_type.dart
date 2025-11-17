/// Specifies which HTTP client implementation to use for network requests.
///
/// This enum allows switching between different HTTP client implementations,
/// each with different capabilities and performance characteristics.
enum HttpClientType {
  /// Uses the standard Dart `http` package (default).
  ///
  /// - Pros: Lightweight, widely used, stable
  /// - Cons: Limited protocol support (HTTP/1.1 only)
  /// - Protocols: HTTP/1.1
  defaultHttp,

  /// Uses the `dio` package for enhanced features with HTTP/2 support.
  ///
  /// HTTP/2 is automatically negotiated via ALPN during TLS handshake on HTTPS
  /// connections. The underlying dart:io HttpClient supports HTTP/2 natively.
  ///
  /// - Pros: Rich feature set, interceptors, better error handling, HTTP/2 multiplexing
  /// - Cons: Larger footprint than default http package
  /// - Protocols: HTTP/1.1 (HTTP and HTTPS), HTTP/2 (HTTPS only, via ALPN)
  /// - Note: HTTP/2 requires HTTPS and server support
  dio,
}
