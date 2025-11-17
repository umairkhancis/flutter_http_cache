import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

import 'curl_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('Initializing HTTP cache...', name: 'example_app');

  // Initialize the cache
  final cache = HttpCache(
    config: const CacheConfig(
      maxMemorySize: 1 * 1024,
      // 1KB
      maxDiskSize: 1 * 1024 * 1024,
      // 1MB
      enableHeuristicFreshness: true,
      serveStaleOnError: true,
      enableLogging: true,
      // Enable logging for debugging
      useDio: true,
    ),
  );

  await cache.initialize();

  developer.log('Cache initialized successfully', name: 'example_app');

  runApp(MyApp(cache: cache));
}

class MyApp extends StatelessWidget {
  final HttpCache cache;

  const MyApp({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTTP Cache Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: CacheDemoPage(cache: cache),
    );
  }
}

class CacheDemoPage extends StatefulWidget {
  final HttpCache cache;

  const CacheDemoPage({super.key, required this.cache});

  @override
  State<CacheDemoPage> createState() => _CacheDemoPageState();
}

class _CacheDemoPageState extends State<CacheDemoPage> {
  final _curlController = TextEditingController();
  final _curlParser = CurlParser();
  String _responseText = '';
  String _cacheStatus = '';
  bool _loading = false;
  Map<String, dynamic>? _cacheStats;
  CachePolicy _selectedCachePolicy = CachePolicy.standard;

  @override
  void initState() {
    super.initState();
    _updateCacheStats();
  }

  @override
  void dispose() {
    _curlController.dispose();
    super.dispose();
  }

  Future<void> _updateCacheStats() async {
    final stats = await widget.cache.getStats();
    setState(() {
      _cacheStats = stats;
    });
  }

  Future<void> _makeRequest() async {
    if (_curlController.text.isEmpty) {
      setState(() {
        _responseText = 'Please enter a cURL command.';
      });
      return;
    }

    developer.log(
      'Making request from cURL command with policy: ${_selectedCachePolicy.name}',
      name: 'example_app',
    );

    setState(() {
      _loading = true;
      _responseText = '';
      _cacheStatus = '';
    });

    final client = CachedHttpClient(
      cache: widget.cache,
      defaultCachePolicy: _selectedCachePolicy,
    );

    try {
      final request = await _curlParser.parse(_curlController.text);

      // Build debug info for UI display
      final debugInfo = StringBuffer();
      debugInfo.writeln('Method: ${request.method}');
      debugInfo.writeln('URL: ${request.url}');
      debugInfo.writeln('\nHeaders:');
      request.headers.forEach((key, value) {
        debugInfo.writeln('  $key: $value');
      });
      if (request.body.isNotEmpty) {
        debugInfo.writeln('\nBody: ${request.body}');
      }

      // Log the parsed request details for debugging
      developer.log('Parsed Request Details:', name: 'example_app');
      developer.log('  Method: ${request.method}', name: 'example_app');
      developer.log('  URL: ${request.url}', name: 'example_app');
      developer.log('  Headers:', name: 'example_app');
      request.headers.forEach((key, value) {
        developer.log('    $key: $value', name: 'example_app');
      });
      if (request.body.isNotEmpty) {
        developer.log('  Body: ${request.body}', name: 'example_app');
      }

      // Start timing
      final startTime = DateTime.now();

      final response = await client.send(request);

      developer.log(
        'Response received (status: ${response.statusCode})',
        name: 'example_app',
      );

      final cacheHeader = response.headers['x-cache'] ?? 'MISS';
      final responseBody = await response.stream.bytesToString();

      // Calculate latency
      final endTime = DateTime.now();
      final latencyMs = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _responseText = responseBody;
        _cacheStatus = 'Cache: $cacheHeader, Latency: ${latencyMs}ms';
        _loading = false;
      });

      developer.log('Request completed successfully', name: 'example_app');

      await _updateCacheStats();
    } catch (e, stackTrace) {
      developer.log(
        'Request failed',
        name: 'example_app',
        error: e,
        stackTrace: stackTrace,
      );

      setState(() {
        _responseText = 'Error: $e';
        _loading = false;
      });
    } finally {
      client.close();
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

  Future<void> _clearExpired() async {
    await widget.cache.clearExpired();
    await _updateCacheStats();
    setState(() {
      _cacheStatus = 'Expired entries cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('HTTP Cache Demo'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              // cURL Input
              TextField(
                controller: _curlController,
                maxLines: 6,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: 'cURL Command (paste multi-line curl)',
                  border: OutlineInputBorder(),
                  hintText:
                      'curl --location \'https://api.example.com\' \\\n--header \'X-Device-Source: 4\'',
                ),
              ),
              const SizedBox(height: 8),
              // Example curl command
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Try this example:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'curl --location \'https://jsonplaceholder.typicode.com/posts/1\' \\\n--header \'Content-Type: application/json\'',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Cache Policy Dropdown
              DropdownButtonFormField<CachePolicy>(
                value: _selectedCachePolicy,
                decoration: const InputDecoration(
                  labelText: 'Cache Policy',
                  border: OutlineInputBorder(),
                ),
                items:
                    CachePolicy.values.map((policy) {
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
              ElevatedButton(
                onPressed: _loading ? null : _makeRequest,
                child: const Text('Make Request'),
              ),
              const SizedBox(height: 16),

              // Cache Management
              const Text(
                'Cache Management:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _clearCache,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Clear All'),
                  ),
                  ElevatedButton(
                    onPressed: _clearExpired,
                    child: const Text('Clear Expired'),
                  ),
                ],
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
                      child: Text(
                        _responseText,
                        style: const TextStyle(fontSize: 12),
                      ),
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
