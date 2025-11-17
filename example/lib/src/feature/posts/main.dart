import 'dart:developer' as developer;

import 'package:example/src/feature/posts/presentation/pages/posts_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

/// Entry point for the BLoC example_a demonstrating flutter_http_cache
///
/// This example_a demonstrates:
/// - Clean Architecture with separation of concerns
/// - BLoC pattern for state management
/// - Dependency injection
/// - HTTP caching with flutter_http_cache
/// - SOLID principles
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log(
    'Initializing HTTP cache for BLoC example_a...',
    name: 'bloc_example',
  );

  // Initialize the HTTP cache
  final cache = HttpCache(
    config: const CacheConfig(
      maxMemorySize: 5 * 1024 * 1024,
      // 5MB memory cache
      maxDiskSize: 50 * 1024 * 1024,
      // 50MB disk cache
      enableHeuristicFreshness: true,
      serveStaleOnError: true,
      enableLogging: true,
      useDio: false, // Using standard HTTP client
    ),
  );

  await cache.initialize();

  developer.log('Cache initialized successfully', name: 'bloc_example');

  runApp(FeatureApp(cache: cache));
}

/// Main application widget with dependency injection
class FeatureApp extends StatelessWidget {
  final HttpCache cache;

  const FeatureApp({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter HTTP Cache - Feature Demo App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: PostsHome(cache: cache),
    );
  }
}
