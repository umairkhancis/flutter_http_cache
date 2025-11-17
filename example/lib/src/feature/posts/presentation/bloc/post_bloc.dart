import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/post_repository_impl.dart';
import '../../domain/repositories/post_repository.dart';
import 'post_event.dart';
import 'post_state.dart';

/// BLoC for managing Post state and events
///
/// This class follows the Single Responsibility Principle by only handling
/// business logic and state management for posts
class PostBloc extends Bloc<PostEvent, PostState> {
  final PostRepository repository;

  PostBloc({required this.repository}) : super(const PostInitial()) {
    // Register event handlers
    on<LoadPostsEvent>(_onLoadPosts);
    on<RefreshPostsEvent>(_onRefreshPosts);
    on<LoadPostByIdEvent>(_onLoadPostById);
  }

  /// Handles LoadPostsEvent
  Future<void> _onLoadPosts(
    LoadPostsEvent event,
    Emitter<PostState> emit,
  ) async {
    developer.log('Loading posts', name: 'PostBloc');

    emit(const PostLoading());

    try {
      final posts = await repository.getPosts();

      developer.log(
        'Successfully loaded ${posts.length} posts',
        name: 'PostBloc',
      );

      emit(PostLoaded(posts));
    } on ServerFailure catch (e) {
      developer.log(
        'Server failure',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Server Error',
      ));
    } on NetworkFailure catch (e) {
      developer.log(
        'Network failure',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Network Error',
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error',
        name: 'PostBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(PostError(
        'An unexpected error occurred: ${e.toString()}',
        errorType: 'Unknown Error',
      ));
    }
  }

  /// Handles RefreshPostsEvent
  Future<void> _onRefreshPosts(
    RefreshPostsEvent event,
    Emitter<PostState> emit,
  ) async {
    developer.log('Refreshing posts', name: 'PostBloc');

    // Keep current posts if available while refreshing
    if (state is PostLoaded) {
      emit(PostRefreshing((state as PostLoaded).posts));
    } else {
      emit(const PostLoading());
    }

    try {
      final posts = await repository.getPosts();

      developer.log(
        'Successfully refreshed ${posts.length} posts',
        name: 'PostBloc',
      );

      emit(PostLoaded(posts));
    } on ServerFailure catch (e) {
      developer.log(
        'Server failure during refresh',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Server Error',
      ));
    } on NetworkFailure catch (e) {
      developer.log(
        'Network failure during refresh',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Network Error',
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during refresh',
        name: 'PostBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(PostError(
        'An unexpected error occurred: ${e.toString()}',
        errorType: 'Unknown Error',
      ));
    }
  }

  /// Handles LoadPostByIdEvent
  Future<void> _onLoadPostById(
    LoadPostByIdEvent event,
    Emitter<PostState> emit,
  ) async {
    developer.log('Loading post ${event.postId}', name: 'PostBloc');

    emit(const PostLoading());

    try {
      final post = await repository.getPostById(event.postId);

      developer.log(
        'Successfully loaded post: ${post.title}',
        name: 'PostBloc',
      );

      emit(PostDetailLoaded(post));
    } on ServerFailure catch (e) {
      developer.log(
        'Server failure',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Server Error',
      ));
    } on NetworkFailure catch (e) {
      developer.log(
        'Network failure',
        name: 'PostBloc',
        error: e,
      );

      emit(PostError(
        e.message,
        errorType: 'Network Error',
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error',
        name: 'PostBloc',
        error: e,
        stackTrace: stackTrace,
      );

      emit(PostError(
        'An unexpected error occurred: ${e.toString()}',
        errorType: 'Unknown Error',
      ));
    }
  }
}
