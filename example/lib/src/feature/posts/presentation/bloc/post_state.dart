import 'package:equatable/equatable.dart';

import '../../domain/entities/post.dart';

/// Base class for all Post states
abstract class PostState extends Equatable {
  const PostState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any events are processed
class PostInitial extends PostState {
  const PostInitial();
}

/// State when posts are being loaded
class PostLoading extends PostState {
  const PostLoading();
}

/// State when posts are successfully loaded
class PostLoaded extends PostState {
  final List<Post> posts;
  final bool isFromCache;

  const PostLoaded(this.posts, {this.isFromCache = false});

  @override
  List<Object?> get props => [posts, isFromCache];
}

/// State when a single post is loaded
class PostDetailLoaded extends PostState {
  final Post post;
  final bool isFromCache;

  const PostDetailLoaded(this.post, {this.isFromCache = false});

  @override
  List<Object?> get props => [post, isFromCache];
}

/// State when there's an error loading posts
class PostError extends PostState {
  final String message;
  final String? errorType;

  const PostError(this.message, {this.errorType});

  @override
  List<Object?> get props => [message, errorType];
}

/// State when posts are being refreshed
class PostRefreshing extends PostState {
  final List<Post> currentPosts;

  const PostRefreshing(this.currentPosts);

  @override
  List<Object?> get props => [currentPosts];
}
