// lib/models/document.dart
class Document {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? filePath;
  final int? fileSize;
  final String? fileType;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isShared;
  final int version;
  final String ownerId;

  Document({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.filePath,
    this.fileSize,
    this.fileType,
    required this.createdAt,
    required this.modifiedAt,
    this.isShared = false,
    this.version = 1,
    required this.ownerId,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    try {
      return Document(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        category: json['category']?.toLowerCase() ?? 'other',
        filePath: json['file_path'],
        fileSize: json['file_size'],
        fileType: json['file_type'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        modifiedAt: json['modified_at'] != null
            ? DateTime.parse(json['modified_at'])
            : DateTime.now(),
        isShared: json['is_shared'] ?? false,
        version: json['version'] ?? 1,
        ownerId: json['owner_id'] ?? '',
      );
    } catch (e, stackTrace) {
      print('Error parsing Document from JSON: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'file_path': filePath,
      'file_size': fileSize,
      'file_type': fileType,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt.toIso8601String(),
      'is_shared': isShared,
      'version': version,
      'owner_id': ownerId,
    };
  }

  Document copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? filePath,
    int? fileSize,
    String? fileType,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isShared,
    int? version,
    String? ownerId,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isShared: isShared ?? this.isShared,
      version: version ?? this.version,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  @override
  String toString() {
    return 'Document(id: $id, name: $name, category: $category, version: $version)';
  }
}
