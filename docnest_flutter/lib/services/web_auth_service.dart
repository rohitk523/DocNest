// lib/services/web_auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../config/environment.dart' as env;

class WebAuthService {
  static final WebAuthService _instance = WebAuthService._internal();
  factory WebAuthService() => _instance;
  WebAuthService._internal();

  final _storage = const FlutterSecureStorage();
  late html.WindowBase _popupWin;

  static const String _googleClientId = env.Environment.googleClientId;

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final token = await _handleGoogleSignIn();
      if (token == null) {
        throw Exception('Google Sign In was canceled');
      }

      print('Sending token to backend: $token'); // Debug log

      final response = await http.post(
        Uri.parse('${ApiConfig.authUrl}/google/signin'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'token': token}),
      );

      print('Backend response status: ${response.statusCode}'); // Debug log
      print('Backend response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData != null) {
          await _persistUserSession(responseData);
          return responseData;
        } else {
          throw Exception('Invalid response from server');
        }
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ?? 'Google sign in failed');
      }
    } catch (e, stackTrace) {
      print('Error during Google Sign In: $e'); // Debug log
      print('Stack trace: $stackTrace'); // Debug log

      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Failed to sign in with Google: ${e.toString()}');
    }
  }

  String _generateNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<String?> _handleGoogleSignIn() async {
    final completer = Completer<String?>();

    // Set up Google Sign-In parameters
    final params = {
      'client_id': _googleClientId,
      'response_type': 'id_token',
      'redirect_uri': Uri.base.origin + '/auth.html',
      'scope': 'email profile',
      'prompt': 'select_account',
      'nonce': _generateNonce() // Add this
    };

    // Build auth URL
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', params);

    // Calculate popup position
    final width = 500;
    final height = 600;
    final left = (html.window.screen!.width! - width) ~/ 2;
    final top = (html.window.screen!.height! - height) ~/ 2;

    // Open popup
    _popupWin = html.window.open(url.toString(), 'Google Sign In',
        'width=$width,height=$height,left=$left,top=$top,popup=yes,location=yes');

    // Listen for messages from popup
    final subscription = html.window.onMessage.listen((event) {
      if (event.data != null &&
          event.data.toString().startsWith('google-token:')) {
        final token = event.data.toString().substring('google-token:'.length);
        if (!completer.isCompleted) {
          completer.complete(token);
        }
      }
    });

    // Check for popup closure
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_popupWin.closed ?? false) {
        timer.cancel();
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    return completer.future;
  }

  Future<void> _persistUserSession(Map<String, dynamic> responseData) async {
    try {
      if (responseData['access_token'] != null) {
        await _storage.write(
            key: 'auth_token', value: responseData['access_token'].toString());
      }

      if (responseData['user'] != null) {
        await _storage.write(
            key: 'user_data', value: json.encode(responseData['user']));
      }
    } catch (e) {
      print('Error persisting session: $e');
      throw Exception('Failed to save session data');
    }
  }

  Future<void> signOut() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        try {
          await http.post(
            Uri.parse('${ApiConfig.authUrl}/logout'),
            headers: ApiConfig.authHeaders(token),
          );
        } catch (e) {
          print('Error calling logout endpoint: $e');
        }
      }
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<String?> getStoredToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getStoredToken();
    if (token == null) return false;

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
}
