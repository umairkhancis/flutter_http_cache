import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/post_bloc.dart';
import '../bloc/post_event.dart';
import '../bloc/post_state.dart';
import '../widgets/post_card.dart';

/// Screen to display a list of posts using BLoC pattern
///
/// This screen demonstrates the flutter_http_cache library integration
/// with BLoC architecture
class PostsListScreen extends StatefulWidget {
  const PostsListScreen({super.key});

  @override
  State<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends State<PostsListScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial load after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bloc = context.read<PostBloc>();
        if (bloc.state is PostInitial) {
          bloc.add(const LoadPostsEvent());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<PostBloc>().add(const RefreshPostsEvent());
            },
          ),
        ],
      ),
      body: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          if (state is PostInitial || state is PostLoading) {
            return const _LoadingView();
          } else if (state is PostRefreshing) {
            return _PostsListView(
              posts: state.currentPosts,
              isRefreshing: true,
            );
          } else if (state is PostLoaded) {
            return _PostsListView(
              posts: state.posts,
              isFromCache: state.isFromCache,
            );
          } else if (state is PostError) {
            return _ErrorView(
              message: state.message,
              errorType: state.errorType,
              onRetry: () {
                context.read<PostBloc>().add(const LoadPostsEvent());
              },
            );
          }

          return const Center(
            child: Text('Unknown state'),
          );
        },
      ),
    );
  }
}

/// Loading view widget
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading posts...'),
        ],
      ),
    );
  }
}

/// Posts list view widget
class _PostsListView extends StatelessWidget {
  final List posts;
  final bool isFromCache;
  final bool isRefreshing;

  const _PostsListView({
    required this.posts,
    this.isFromCache = false,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cache status banner
        if (isFromCache)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Icon(
                  Icons.cached,
                  size: 16,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Loaded from cache',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Posts count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            '${posts.length} posts',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Posts list
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<PostBloc>().add(const RefreshPostsEvent());
                  // Wait for the refresh to complete
                  await context.read<PostBloc>().stream.firstWhere(
                        (state) => state is! PostRefreshing,
                      );
                },
                child: ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return PostCard(
                      post: post,
                      onTap: () {
                        _showPostDetail(context, post);
                      },
                    );
                  },
                ),
              ),
              if (isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPostDetail(BuildContext context, dynamic post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // User badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'User ${post.userId}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Body
              Text(
                post.body,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Post ID
              Text(
                'Post ID: ${post.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error view widget
class _ErrorView extends StatelessWidget {
  final String message;
  final String? errorType;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    this.errorType,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            if (errorType != null) ...[
              Text(
                errorType!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
