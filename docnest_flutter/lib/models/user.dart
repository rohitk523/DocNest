// lib/models/user.dart
class User {
  final String id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isGoogleUser;
  final String? profilePicture;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final List<String> customCategories; // Added for custom categories

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
    required this.isGoogleUser,
    this.profilePicture,
    required this.createdAt,
    this.lastLogin,
    this.customCategories = const [], // Default to empty list
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      isActive: json['is_active'] ?? false,
      isGoogleUser: json['is_google_user'] ?? false,
      profilePicture: json['profile_picture'],
      createdAt: DateTime.parse(json['created_at']),
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      customCategories:
          (json['custom_categories'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'is_active': isActive,
      'is_google_user': isGoogleUser,
      'profile_picture': profilePicture,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'custom_categories': customCategories,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    bool? isActive,
    bool? isGoogleUser,
    String? profilePicture,
    DateTime? createdAt,
    DateTime? lastLogin,
    List<String>? customCategories,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      customCategories: customCategories ?? this.customCategories,
    );
  }
}
