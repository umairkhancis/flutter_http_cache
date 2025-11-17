import 'dart:convert';

import '../../domain/entities/post.dart';

/// Post model for data layer with JSON serialization
///
/// This model extends the domain entity and adds JSON serialization capabilities
class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.body,
  });

  /// Creates a PostModel from JSON map
  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  /// Converts PostModel to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
    };
  }

  /// Creates a PostModel from a Post entity
  factory PostModel.fromEntity(Post post) {
    return PostModel(
      id: post.id,
      userId: post.userId,
      title: post.title,
      body: post.body,
    );
  }

  /// Parses a JSON string to PostModel
  factory PostModel.fromJsonString(String jsonString) {
    return PostModel.fromJson(
      json.decode(jsonString) as Map<String, dynamic>,
    );
  }

  /// Converts PostModel to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }

  /// Parses a list of JSON objects to list of PostModels
  static List<PostModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
