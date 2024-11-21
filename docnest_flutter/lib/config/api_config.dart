// lib/services/api_config.dart
import 'dart:io';

enum Environment { production, staging, development }

class ApiConfig {
  static const bool isProduction = true;

  // You can adjust this based on your build configuration or env variables
  static const environment = Environment.staging;

  static String get baseUrl {
    switch (environment) {
      case Environment.production:
        return 'https://docnest-z9xr.onrender.com/api/v1';

      case Environment.staging:
        return 'https://api.codewithrk.xyz/api/v1'; // Your AWS ECS endpoint

      case Environment.development:
        final deviceIP = Platform.isAndroid ? "10.0.2.2" : "localhost";
        return 'http://$deviceIP:8000/api/v1';

      default:
        return 'https://docnest-z9xr.onrender.com/api/v1';
    }
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
