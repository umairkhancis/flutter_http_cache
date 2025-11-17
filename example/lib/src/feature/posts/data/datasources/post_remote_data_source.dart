import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_http_cache/flutter_http_cache.dart';

import '../models/post_model.dart';

/// Exception thrown when the remote data source fails to fetch data
class RemoteDataSourceException implements Exception {
  final String message;
  final int? statusCode;

  const RemoteDataSourceException(this.message, [this.statusCode]);

  @override
  String toString() => 'RemoteDataSourceException: $message'
      '${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Remote data source for Post data using CachedHttpClient
///
/// This class follows the Single Responsibility Principle by only handling
/// remote data fetching operations
abstract class PostRemoteDataSource {
  /// Fetches all posts from the API
  Future<List<PostModel>> getPosts();

  /// Fetches a single post by ID from the API
  Future<PostModel> getPostById(int id);
}

/// Implementation of PostRemoteDataSource using CachedHttpClient
///
/// This implementation uses the flutter_http_cache library to automatically
/// cache HTTP responses
class PostRemoteDataSourceImpl implements PostRemoteDataSource {
  final CachedHttpClient client;
  final String baseUrl;

  const PostRemoteDataSourceImpl({
    required this.client,
    this.baseUrl = 'https://jsonplaceholder.typicode.com',
  });

  @override
  Future<List<PostModel>> getPosts() async {
    developer.log('Fetching posts from $baseUrl/posts', name: 'PostRemoteDataSource');

    try {
      final uri = Uri.parse('$baseUrl/posts');
      final response = await client.get(uri);

      developer.log(
        'Response received: ${response.statusCode}',
        name: 'PostRemoteDataSource',
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body) as List<dynamic>;
        final posts = PostModel.fromJsonList(jsonList);

        developer.log(
          'Successfully parsed ${posts.length} posts',
          name: 'PostRemoteDataSource',
        );

        return posts;
      } else {
        throw RemoteDataSourceException(
          'Failed to load posts',
          response.statusCode,
        );
      }
    } on RemoteDataSourceException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching posts',
        name: 'PostRemoteDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw RemoteDataSourceException('Network error: ${e.toString()}');
    }
  }

  @override
  Future<PostModel> getPostById(int id) async {
    developer.log('Fetching post $id from $baseUrl/posts/$id', name: 'PostRemoteDataSource');

    try {
      final uri = Uri.parse('$baseUrl/posts/$id');
      final response = await client.get(uri);

      developer.log(
        'Response received: ${response.statusCode}',
        name: 'PostRemoteDataSource',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(response.body) as Map<String, dynamic>;
        final post = PostModel.fromJson(jsonMap);

        developer.log(
          'Successfully parsed post: ${post.title}',
          name: 'PostRemoteDataSource',
        );

        return post;
      } else if (response.statusCode == 404) {
        throw RemoteDataSourceException(
          'Post not found',
          response.statusCode,
        );
      } else {
        throw RemoteDataSourceException(
          'Failed to load post',
          response.statusCode,
        );
      }
    } on RemoteDataSourceException {
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error fetching post',
        name: 'PostRemoteDataSource',
        error: e,
        stackTrace: stackTrace,
      );
      throw RemoteDataSourceException('Network error: ${e.toString()}');
    }
  }
}
