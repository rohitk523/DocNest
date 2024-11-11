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

  User({
    required this.id,
    required this.email,
    this.fullName,
    required this.isActive,
    required this.isGoogleUser,
    this.profilePicture,
    required this.createdAt,
    this.lastLogin,
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
    );
  }
}
