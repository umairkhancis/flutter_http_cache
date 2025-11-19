import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

/// Example demonstrating how to use DioHttpCacheInterceptor
/// with an existing Dio instance.
///
/// This shows how apps already using Dio can simply add the
/// cache interceptor to enable transparent HTTP caching.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('Initializing HTTP cache...', name: 'dio_example');

  // 1. Initialize the cache
  final cache = HttpCache(
    config: const CacheConfig(
      maxMemorySize: 1 * 1024, // 1KB
      maxDiskSize: 1 * 1024 * 1024, // 1MB
      enableHeuristicFreshness: true,
      serveStaleOnError: true,
      enableLogging: true,
    ),
  );

  await cache.initialize();

  developer.log('Cache initialized successfully', name: 'dio_example');

  runApp(DioExampleApp(cache: cache));
}

class DioExampleApp extends StatelessWidget {
  final HttpCache cache;

  const DioExampleApp({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dio Cache Interceptor Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: DioExamplePage(cache: cache),
    );
  }
}

class DioExamplePage extends StatefulWidget {
  final HttpCache cache;

  const DioExamplePage({super.key, required this.cache});

  @override
  State<DioExamplePage> createState() => _DioExamplePageState();
}

class _DioExamplePageState extends State<DioExamplePage> {
  late Dio _dio;
  String _responseText = '';
  String _cacheStatus = '';
  bool _loading = false;
  Map<String, dynamic>? _cacheStats;
  CachePolicy _selectedCachePolicy = CachePolicy.standard;

  @override
  void initState() {
    super.initState();
    _initializeDio();
    _updateCacheStats();
  }

  void _initializeDio() {
    // 2. Create a Dio instance with your existing configuration
    _dio = Dio(BaseOptions(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));

    // 3. Add your existing interceptors
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => developer.log(obj.toString(), name: 'dio'),
    ));

    // 4. Add the DioHttpCacheInterceptor - that's it!
    _dio.interceptors.add(DioHttpCacheInterceptor(widget.cache));

    developer.log('Dio initialized with cache interceptor', name: 'dio_example');
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _updateCacheStats() async {
    final stats = await widget.cache.getStats();
    setState(() {
      _cacheStats = stats;
    });
  }

  Future<void> _makeSimpleRequest() async {
    setState(() {
      _loading = true;
      _responseText = '';
      _cacheStatus = '';
    });

    try {
      final startTime = DateTime.now();

      // Make a simple GET request with the selected cache policy
      final response = await _dio.get(
        '/posts/1',
        options: Options(
          extra: {
            // Optional: Override cache policy per-request
            'cachePolicy': _selectedCachePolicy,
          },
        ),
      );

      final endTime = DateTime.now();
      final latencyMs = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _responseText = response.data.toString();
        final cacheHeader = response.headers.value('x-cache') ?? 'MISS';
        _cacheStatus = 'Cache: $cacheHeader, Latency: ${latencyMs}ms';
        _loading = false;
      });

      await _updateCacheStats();
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _makePostRequest() async {
    setState(() {
      _loading = true;
      _responseText = '';
      _cacheStatus = '';
    });

    try {
      final startTime = DateTime.now();

      // POST requests will invalidate related cache entries
      final response = await _dio.post(
        '/posts',
        data: {
          'title': 'New Post',
          'body': 'This is a new post',
          'userId': 1,
        },
      );

      final endTime = DateTime.now();
      final latencyMs = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _responseText = response.data.toString();
        _cacheStatus = 'POST successful, Latency: ${latencyMs}ms\nRelated cache entries invalidated';
        _loading = false;
      });

      await _updateCacheStats();
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    await widget.cache.clear();
    await _updateCacheStats();
    setState(() {
      _responseText = '';
      _cacheStatus = 'Cache cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Dio Cache Interceptor Example'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Dio Integration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This example shows how to add HTTP caching to an existing Dio setup. '
                        'Simply add DioHttpCacheInterceptor to your interceptors list!',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cache Statistics
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cache Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_cacheStats != null) ...[
                        Text('Entries: ${_cacheStats!['entries']}'),
                        Text('Size: ${_cacheStats!['bytesFormatted']}'),
                        Text('Usage: ${_cacheStats!['cacheUsage']}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cache Policy Dropdown
              DropdownButtonFormField<CachePolicy>(
                value: _selectedCachePolicy,
                decoration: const InputDecoration(
                  labelText: 'Cache Policy',
                  border: OutlineInputBorder(),
                  helperText: 'Optional: Override default cache policy',
                ),
                items: CachePolicy.values.map((policy) {
                  return DropdownMenuItem(
                    value: policy,
                    child: Text(policy.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCachePolicy = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Request Buttons
              const Text(
                'Try Different Requests:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loading ? null : _makeSimpleRequest,
                icon: const Icon(Icons.download),
                label: const Text('GET Request (Cacheable)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loading ? null : _makePostRequest,
                icon: const Icon(Icons.upload),
                label: const Text('POST Request (Invalidates Cache)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Cache Management
              const Text(
                'Cache Management:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _clearCache,
                icon: const Icon(Icons.delete),
                label: const Text('Clear Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Cache Status
              if (_cacheStatus.isNotEmpty) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _cacheStatus,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Response
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_responseText.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 400,
                  ),
                  child: Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12.0),
                      child: SelectableText(
                        _responseText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Code Example
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.code, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Integration Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        '''
// 1. Initialize cache
final cache = HttpCache(
  config: CacheConfig(
    enableLogging: true,
  ),
);
await cache.initialize();

// 2. Create Dio with existing interceptors
final dio = Dio();
dio.interceptors.add(LogInterceptor());

// 3. Add cache interceptor
dio.interceptors.add(
  DioHttpCacheInterceptor(cache),
);

// 4. Use Dio normally - caching is automatic!
final response = await dio.get('/posts/1');

// Optional: Override cache policy per-request
final response = await dio.get(
  '/posts/1',
  options: Options(
    extra: {
      'cachePolicy': CachePolicy.networkFirst,
    },
  ),
);
                        ''',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
