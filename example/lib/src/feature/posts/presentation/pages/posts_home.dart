import 'dart:developer' as developer;

import 'package:example/src/feature/posts/data/datasources/post_remote_data_source.dart';
import 'package:example/src/feature/posts/data/repositories/post_repository_impl.dart';
import 'package:example/src/feature/posts/domain/repositories/post_repository.dart';
import 'package:example/src/feature/posts/presentation/bloc/post_bloc.dart';
import 'package:example/src/feature/posts/presentation/pages/posts_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_http_cache/flutter_http_cache.dart';

/// Home screen with dependency injection setup
class PostsHome extends StatefulWidget {
  final HttpCache cache;

  const PostsHome({super.key, required this.cache});

  @override
  State<PostsHome> createState() => _PostsHomeState();
}

class _PostsHomeState extends State<PostsHome> {
  late CachedHttpClient _httpClient;
  late PostRemoteDataSource _remoteDataSource;
  late PostRepository _repository;

  @override
  void initState() {
    super.initState();
    _setupDependencies();
  }

  /// Setup dependency injection
  ///
  /// This method demonstrates manual dependency injection following
  /// the Dependency Inversion Principle:
  /// - High-level modules (BLoC) depend on abstractions (Repository interface)
  /// - Low-level modules (Repository implementation) depend on abstractions
  void _setupDependencies() {
    developer.log('Setting up dependencies', name: 'bloc_example');

    // Create HTTP client with cache
    _httpClient = CachedHttpClient(
      cache: widget.cache,
      defaultCachePolicy: CachePolicy.standard,
    );

    // Create data source
    _remoteDataSource = PostRemoteDataSourceImpl(client: _httpClient);

    // Create repository
    _repository = PostRepositoryImpl(remoteDataSource: _remoteDataSource);

    developer.log('Dependencies initialized', name: 'bloc_example');
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provide the BLoC to the widget tree
    return BlocProvider(
      create: (context) => PostBloc(repository: _repository),
      child: Builder(
        builder:
            (context) => Scaffold(
              appBar: AppBar(
                title: const Text('HTTP Cache - BLoC Example'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              ),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Flutter HTTP Cache with BLoC',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'This example_a demonstrates clean architecture with:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildFeatureItem(
                              'BLoC Pattern for state management',
                            ),
                            _buildFeatureItem(
                              'Repository pattern with abstraction',
                            ),
                            _buildFeatureItem('Data sources with HTTP caching'),
                            _buildFeatureItem(
                              'SOLID principles implementation',
                            ),
                            _buildFeatureItem('Dependency injection'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cache info card
                    FutureBuilder<Map<String, dynamic>>(
                      future: widget.cache.getStats(),
                      builder: (context, snapshot) {
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cache Statistics',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (snapshot.hasData) ...[
                                  Text('Entries: ${snapshot.data!['entries']}'),
                                  Text(
                                    'Size: ${snapshot.data!['bytesFormatted']}',
                                  ),
                                  Text(
                                    'Usage: ${snapshot.data!['cacheUsage']}',
                                  ),
                                ] else ...[
                                  const Text('Loading cache stats...'),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // View posts button
                    ElevatedButton.icon(
                      onPressed: () {
                        // Capture the PostBloc from current context
                        final postBloc = context.read<PostBloc>();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => BlocProvider.value(
                                  value: postBloc,
                                  child: const PostsListScreen(),
                                ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.article),
                      label: const Text('View Posts'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Clear cache button
                    OutlinedButton.icon(
                      onPressed: () async {
                        await widget.cache.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cache cleared'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          setState(() {}); // Refresh cache stats
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Cache'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
