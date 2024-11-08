// lib/models/document.dart
import 'package:flutter/foundation.dart';

class Document {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? filePath;
  final int? fileSize;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isShared;

  Document({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.filePath,
    this.fileSize,
    required this.createdAt,
    required this.modifiedAt,
    this.isShared = false,
  });

  // Add copyWith method
  Document copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? filePath,
    int? fileSize,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isShared,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isShared: isShared ?? this.isShared,
    );
  }

  // Convert Document instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'file_path': filePath,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt.toIso8601String(),
      'is_shared': isShared,
    };
  }

  // Create Document instance from JSON
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      category: json['category'],
      filePath: json['file_path'],
      fileSize: json['file_size'],
      createdAt: DateTime.parse(json['created_at']),
      modifiedAt: DateTime.parse(json['modified_at']),
      isShared: json['is_shared'] ?? false,
    );
  }

  @override
  String toString() {
    return 'Document(id: $id, name: $name, category: $category)';
  }
}
