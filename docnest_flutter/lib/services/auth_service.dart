// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1/auth';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(json.decode(response.body)['detail'] ?? 'Login failed');
      }
    } catch (e) {
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'full_name': fullName,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign In was cancelled');
      }

      // Get auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to get ID token');
      }

      // Send token to backend
      final response = await http.post(
        Uri.parse('$baseUrl/google/signin'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'token': idToken,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Google Sign In Response: $responseData'); // Debug print
        return responseData;
      } else {
        final error =
            json.decode(response.body)['detail'] ?? 'Google sign in failed';
        print('Google Sign In Error: $error'); // Debug print
        throw Exception(error);
      }
    } catch (e) {
      print('Google Sign In Exception: $e'); // Debug print
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Google
      await _googleSignIn.signOut();

      // You might want to also clear any stored tokens or user data here
    } catch (e) {
      print('Sign Out Error: $e'); // Debug print
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<Map<String, dynamic>> refreshToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/refresh'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            json.decode(response.body)['detail'] ?? 'Token refresh failed');
      }
    } catch (e) {
      throw Exception('Failed to refresh token: $e');
    }
  }

  Future<bool> verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
