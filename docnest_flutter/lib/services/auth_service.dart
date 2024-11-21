// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _storage = const FlutterSecureStorage();

  Future<String?> getStoredToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<Map<String, String>?> getStoredUserData() async {
    final userDataStr = await _storage.read(key: 'user_data');
    if (userDataStr != null) {
      return Map<String, String>.from(json.decode(userDataStr));
    }
    return null;
  }

  Future<void> _persistUserSession(Map<String, dynamic> responseData) async {
    await _storage.write(
        key: 'auth_token', value: responseData['access_token']);
    if (responseData['user'] != null) {
      await _storage.write(
          key: 'user_data', value: json.encode(responseData['user']));
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.authUrl}/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await _persistUserSession(responseData);
        return responseData;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Login failed');
      }
    } catch (e) {
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google Sign In was canceled');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String idToken = googleAuth.idToken!;

      final response = await http.post(
        Uri.parse('${ApiConfig.authUrl}/google/signin'),
        headers: ApiConfig.jsonHeaders,
        body: json.encode({'token': idToken}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await _persistUserSession(responseData);
        return responseData;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Google sign in failed');
      }
    } catch (e) {
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  Future<bool> verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.authUrl}/me'),
        headers: ApiConfig.authHeaders(token),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut(String token) async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.authUrl}/logout'),
        headers: ApiConfig.authHeaders(token),
      );

      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Clear stored credentials
      await _storage.deleteAll();
    } catch (e) {
      print('Error during sign out: $e');
      // Still clear local storage even if server request fails
      await _storage.deleteAll();
    }
  }

  Future<Map<String, dynamic>> refreshToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.authUrl}/refresh'),
        headers: ApiConfig.authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        await _persistUserSession(responseData);
        return responseData;
      } else {
        throw Exception('Token refresh failed');
      }
    } catch (e) {
      throw Exception('Failed to refresh token: ${e.toString()}');
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    return token != null && await verifyToken(token);
  }
}
