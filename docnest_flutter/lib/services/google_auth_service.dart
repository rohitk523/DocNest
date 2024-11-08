import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google Sign In was canceled');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/auth/google/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': googleAuth.idToken}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            json.decode(response.body)['detail'] ?? 'Authentication failed');
      }
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}
