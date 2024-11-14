// lib/services/api_config.dart
import 'dart:io';

class ApiConfig {
  static const bool isProduction = true;

  static String get baseUrl {
    if (isProduction) {
      return 'https://docnest-z9xr.onrender.com/api/v1';
    }
    // Development URL (for local testing)
    final deviceIP = Platform.isAndroid ? "10.0.2.2" : "localhost";
    return 'http://$deviceIP:8000/api/v1';
  }

  static String get authUrl => '$baseUrl/auth';
  static String get documentsUrl => '$baseUrl/documents/';

  // Common headers
  static Map<String, String> get jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      };

  static Map<String, String> authHeaders(String token) => {
        ...jsonHeaders,
        'Authorization': 'Bearer $token',
      };
}
