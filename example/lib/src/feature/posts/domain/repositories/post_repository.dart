import '../entities/post.dart';

/// Repository interface for Post data operations
///
/// This interface follows the Dependency Inversion Principle by defining
/// the contract that data layer must implement
abstract class PostRepository {
  /// Fetches all posts from the remote data source
  ///
  /// Returns a list of [Post] entities on success
  /// Throws an exception on failure
  Future<List<Post>> getPosts();

  /// Fetches a single post by its ID
  ///
  /// Returns a [Post] entity on success
  /// Throws an exception on failure
  Future<Post> getPostById(int id);
}
