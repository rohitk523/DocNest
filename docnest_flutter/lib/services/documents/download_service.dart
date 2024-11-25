import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/document.dart';
import '../../utils/document_filename_utils.dart';
import 'cache_service.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_snackbar.dart';

class DocumentDownloadService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );
  }

  static Future<void> showDownloadNotification(String filename) async {
    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Download Complete',
      'File saved to Downloads: $filename',
      notificationDetails,
      payload: filename,
    );
  }

  // Helper function to get unique filename
  static String getUniqueFilename(String originalPath) {
    final File file = File(originalPath);
    if (!file.existsSync()) {
      return originalPath;
    }

    final String dir = file.parent.path;
    final String extension = file.path.split('.').last;
    final String nameWithoutExtension =
        file.path.split('/').last.split('.').first;

    int counter = 1;
    String newPath;

    do {
      newPath = '$dir/$nameWithoutExtension ($counter).$extension';
      counter++;
    } while (File(newPath).existsSync());

    return newPath;
  }

  static Future<void> downloadDocument(
    BuildContext context,
    Document document,
    String token, {
    bool autoRename = true, // Add parameter to control renaming behavior
  }) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Downloading document...'),
            ],
          ),
        ),
      );

      final filename = DocumentFilenameUtils.getProperFilename(document);
      final cacheService = CacheService();
      File? cachedFile = await cacheService.getCachedDocumentByName(filename);

      if (await Permission.storage.request().isGranted) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        final originalFilePath = '${downloadDir.path}/$filename';

        // Check if file already exists
        if (File(originalFilePath).existsSync() && !autoRename) {
          if (context.mounted) {
            Navigator.pop(context); // Dismiss loading dialog
            CustomSnackBar.showError(
              context: context,
              title: 'File Already Exists',
              message:
                  'A file with this name already exists in Downloads folder',
              actionLabel: 'Rename & Download',
              onAction: () => downloadDocument(
                context,
                document,
                token,
                autoRename: true,
              ),
            );
          }
          return;
        }

        // Get unique filepath if autoRename is true
        final filePath =
            autoRename ? getUniqueFilename(originalFilePath) : originalFilePath;

        final file = File(filePath);

        if (cachedFile == null || !await cachedFile.exists()) {
          // Download from server if not cached
          final response = await http.get(
            Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
            headers: ApiConfig.authHeaders(token),
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to download document');
          }

          // Save file and cache
          await file.writeAsBytes(response.bodyBytes);
          await cacheService.cacheDocumentWithName(
              filename, response.bodyBytes);
        } else {
          // Copy from cache
          await cachedFile.copy(file.path);
        }

        final savedFilename = file.path.split('/').last;

        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading dialog
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Download Complete',
            message: 'File saved to Downloads folder:\n$savedFilename',
          );
          await showDownloadNotification(savedFilename);
        }
      } else {
        throw Exception('Storage permission required');
      }
    } catch (e) {
      print('Download error: $e');
      if (context.mounted) {
        Navigator.pop(context);
        CustomSnackBar.showError(
          context: context,
          title: 'Download Failed',
          message: 'Error: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => downloadDocument(context, document, token),
        );
      }
    }
  }
}
