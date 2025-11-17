import 'package:equatable/equatable.dart';

/// Base class for all Post events
abstract class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all posts
class LoadPostsEvent extends PostEvent {
  const LoadPostsEvent();
}

/// Event to refresh posts (force network fetch)
class RefreshPostsEvent extends PostEvent {
  const RefreshPostsEvent();
}

/// Event to load a specific post by ID
class LoadPostByIdEvent extends PostEvent {
  final int postId;

  const LoadPostByIdEvent(this.postId);

  @override
  List<Object?> get props => [postId];
}
