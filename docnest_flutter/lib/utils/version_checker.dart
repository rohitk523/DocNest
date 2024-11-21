// lib/utils/version_checker.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class VersionChecker {
  static const String PLAY_STORE_URL =
      'market://details?id=com.codewithrk.docnest_flutter';
  static const String FALLBACK_URL =
      'https://play.google.com/store/apps/details?id=com.codewithrk.docnest_flutter';

  static Future<void> checkVersion(BuildContext context) async {
    try {
      // Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Check version with backend
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/version-check'),
        headers: ApiConfig.jsonHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final minVersion = data['minVersion'];
        final latestVersion = data['latestVersion'];
        final forceUpdate = data['forceUpdate'] ?? false;

        if (forceUpdate && _isVersionLower(currentVersion, minVersion)) {
          _showForceUpdateDialog(context);
        } else if (_isVersionLower(currentVersion, latestVersion)) {
          _showUpdateAvailableDialog(context);
        }
      }
    } catch (e) {
      debugPrint('Error checking version: $e');
    }
  }

  static bool _isVersionLower(String current, String compare) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> compareParts = compare.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < compareParts[i]) return true;
      if (currentParts[i] > compareParts[i]) return false;
    }
    return false;
  }

  static void _showForceUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Update Required'),
          content: const Text(
            'A new version of DocNest is required to continue. Please update to the latest version.',
          ),
          actions: [
            TextButton(
              onPressed: () => _openStore(),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  static void _showUpdateAvailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of DocNest is available. Would you like to update now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () => _openStore(),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  static Future<void> _openStore() async {
    try {
      final uri = Uri.parse(PLAY_STORE_URL);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        final fallbackUri = Uri.parse(FALLBACK_URL);
        await launchUrl(fallbackUri);
      }
    } catch (e) {
      debugPrint('Error opening store: $e');
    }
  }
}
