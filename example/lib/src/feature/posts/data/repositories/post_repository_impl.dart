import 'dart:developer' as developer;

import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/post_remote_data_source.dart';

/// Repository failure base class
abstract class RepositoryFailure implements Exception {
  final String message;

  const RepositoryFailure(this.message);

  @override
  String toString() => message;
}

/// Server failure when the remote server returns an error
class ServerFailure extends RepositoryFailure {
  final int? statusCode;

  const ServerFailure(super.message, [this.statusCode]);

  @override
  String toString() => 'ServerFailure: $message'
      '${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Network failure when there's a connection issue
class NetworkFailure extends RepositoryFailure {
  const NetworkFailure(super.message);

  @override
  String toString() => 'NetworkFailure: $message';
}

/// Cache failure when cache operations fail
class CacheFailure extends RepositoryFailure {
  const CacheFailure(super.message);

  @override
  String toString() => 'CacheFailure: $message';
}

/// Implementation of PostRepository
///
/// This class follows the Single Responsibility Principle by coordinating
/// between data sources and handling error mapping
class PostRepositoryImpl implements PostRepository {
  final PostRemoteDataSource remoteDataSource;

  const PostRepositoryImpl({
    required this.remoteDataSource,
  });

  @override
  Future<List<Post>> getPosts() async {
    try {
      developer.log('Fetching posts from repository', name: 'PostRepository');

      final posts = await remoteDataSource.getPosts();

      developer.log(
        'Successfully fetched ${posts.length} posts',
        name: 'PostRepository',
      );

      return posts;
    } on RemoteDataSourceException catch (e, stackTrace) {
      developer.log(
        'Data source exception',
        name: 'PostRepository',
        error: e,
        stackTrace: stackTrace,
      );

      if (e.statusCode != null) {
        throw ServerFailure(e.message, e.statusCode);
      } else {
        throw NetworkFailure(e.message);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected exception',
        name: 'PostRepository',
        error: e,
        stackTrace: stackTrace,
      );

      throw NetworkFailure('Unexpected error: ${e.toString()}');
    }
  }

  @override
  Future<Post> getPostById(int id) async {
    try {
      developer.log('Fetching post $id from repository', name: 'PostRepository');

      final post = await remoteDataSource.getPostById(id);

      developer.log(
        'Successfully fetched post: ${post.title}',
        name: 'PostRepository',
      );

      return post;
    } on RemoteDataSourceException catch (e, stackTrace) {
      developer.log(
        'Data source exception',
        name: 'PostRepository',
        error: e,
        stackTrace: stackTrace,
      );

      if (e.statusCode != null) {
        throw ServerFailure(e.message, e.statusCode);
      } else {
        throw NetworkFailure(e.message);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected exception',
        name: 'PostRepository',
        error: e,
        stackTrace: stackTrace,
      );

      throw NetworkFailure('Unexpected error: ${e.toString()}');
    }
  }
}
