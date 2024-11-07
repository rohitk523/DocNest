// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../models/user.dart';

// class AuthService {
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: [
//       'email',
//       'profile',
//     ],
//   );
  
//   final String _baseUrl = 'http://your-api-url/api/v1';

//   Future<User?> signInWithGoogle() async {
//     try {
//       final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) return null;

//       final GoogleSignInAuthentication googleAuth = 
//           await googleUser.authentication;

//       // Send token to your backend
//       final response = await http.post(
//         Uri.parse('$_baseUrl/auth/google'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'token': googleAuth.idToken,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final userData = json.decode(response.body);
//         // Save auth token
//         await _saveAuthToken(userData['access_token']);
//         return User.fromJson(userData['user']);
//       } else {
//         throw Exception('Failed to sign in with Google');
//       }
//     } catch (e) {
//       print('Error signing in with Google: $e');
//       return null;
//     }
//   }

//   Future<void> signOut() async {
//     await _googleSignIn.signOut();
//     await _clearAuthToken();
//   }

//   Future<void> _saveAuthToken(String token) async {
//     // Implement secure token storage (e.g., using flutter_secure_storage)
//   }

//   Future<void> _clearAuthToken() async {
//     // Implement token cleanup
//   }
// }