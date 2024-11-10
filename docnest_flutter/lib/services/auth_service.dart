// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

class AuthService {
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1/auth';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      // Try to sign out first to force account picker
      try {
        final isSignedIn = await _googleSignIn.isSignedIn();
        if (isSignedIn) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        // Ignore sign out errors
      }

      // Trigger new sign in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google Sign In was canceled');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String idToken = googleAuth.idToken!;

      final response = await http.post(
        Uri.parse('$baseUrl/google/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': idToken,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            json.decode(response.body)['detail'] ?? 'Google sign in failed');
      }
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

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

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            json.decode(response.body)['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      // Check if user is signed in first
      final isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        // Try to sign out gracefully
        try {
          await _googleSignIn.signOut();
        } catch (e) {
          print('Google sign out error (non-fatal): $e');
        }
      }

      // Optional: Make a call to your backend to invalidate the session
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Content-Type': 'application/json',
            // Add your authorization header if required
          },
        );

        if (response.statusCode != 200) {
          print('Backend logout warning: ${response.body}');
        }
      } catch (e) {
        print('Backend logout error (non-fatal): $e');
      }
    } catch (e) {
      // Log the error but don't throw
      print('Sign out error (non-fatal): $e');
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
