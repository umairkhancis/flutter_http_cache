import 'package:equatable/equatable.dart';

/// Post entity representing a blog post
///
/// This is a domain entity that is independent of any data source
class Post extends Equatable {
  final int id;
  final int userId;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  @override
  List<Object?> get props => [id, userId, title, body];

  @override
  String toString() {
    return 'Post(id: $id, userId: $userId, title: $title, body: ${body.substring(0, body.length > 50 ? 50 : body.length)}...)';
  }
}
