import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
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

  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // For Android 13+, we actually don't need storage permission
        // We only need manage external storage
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        // Below Android 13
        var status = await Permission.storage.request();
        if (status.isDenied) {
          // Try requesting manage external storage as fallback
          status = await Permission.manageExternalStorage.request();
        }
        return status.isGranted ||
            await Permission.manageExternalStorage.isGranted;
      }
    }
    return true;
  }

  static Future<String?> _getDownloadPath() async {
    try {
      if (Platform.isAndroid) {
        // Try common download paths
        final List<String> possiblePaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];

        // Add the external storage path if available
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final externalPath = externalDir.path.replaceAll(
            RegExp(r'Android/data/.*?/files'),
            'Download',
          );
          possiblePaths.insert(0, externalPath);
        }

        // Try each path
        for (final path in possiblePaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            print('Using existing download path: $path');
            return path;
          } else {
            try {
              await dir.create(recursive: true);
              print('Created download path: $path');
              return path;
            } catch (e) {
              print('Failed to create directory at $path: $e');
              continue;
            }
          }
        }

        // Fallback to the first path if none work
        final fallbackPath = '/storage/emulated/0/Download';
        final fallbackDir = Directory(fallbackPath);
        await fallbackDir.create(recursive: true);
        return fallbackPath;
      }

      // For iOS or other platforms
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print('Error getting download path: $e');
      return null;
    }
  }

  static Future<void> _showDownloadDialog(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
              SizedBox(height: 20),
              Text(
                'Downloading document...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> downloadDocument(
    BuildContext context,
    Document document,
    String token, {
    bool autoRename = true,
  }) async {
    try {
      _showDownloadDialog(context);

      // Request permissions first
      if (!await _requestStoragePermission()) {
        throw Exception(
            'Storage permission required. Please grant permission in Settings.');
      }

      // Get download path
      final downloadPath = await _getDownloadPath();
      if (downloadPath == null) {
        throw Exception('Could not access Downloads directory');
      }

      final filename = DocumentFilenameUtils.getProperFilename(document);
      final cacheService = CacheService();
      File? cachedFile = await cacheService.getCachedDocumentByName(filename);

      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final originalFilePath = '${downloadDir.path}/$filename';

      // Check for existing file
      if (File(originalFilePath).existsSync() && !autoRename) {
        if (context.mounted) {
          Navigator.pop(context);
          CustomSnackBar.showError(
            context: context,
            title: 'File Already Exists',
            message: 'A file with this name already exists in Downloads folder',
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

      final filePath =
          autoRename ? getUniqueFilename(originalFilePath) : originalFilePath;
      final file = File(filePath);

      try {
        if (cachedFile == null || !await cachedFile.exists()) {
          final response = await http.get(
            Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
            headers: ApiConfig.authHeaders(token),
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to download document');
          }

          await file.writeAsBytes(response.bodyBytes);
          await cacheService.cacheDocumentWithName(
              filename, response.bodyBytes);
        } else {
          await cachedFile.copy(file.path);
        }

        final savedFilename = file.path.split('/').last;

        if (context.mounted) {
          Navigator.pop(context);
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Download Complete',
            message: 'File saved to Downloads folder:\n$savedFilename',
          );
          await showDownloadNotification(savedFilename);
        }
      } catch (e) {
        print('File operation error: $e');
        throw Exception('Failed to save file: ${e.toString()}');
      }
    } catch (e) {
      print('Download error: $e');
      if (context.mounted) {
        Navigator.pop(context);

        if (e.toString().contains('permission')) {
          CustomSnackBar.showError(
            context: context,
            title: 'Permission Required',
            message: 'Storage permission is required to download files',
            actionLabel: 'Open Settings',
            onAction: () => openAppSettings(),
          );
        } else {
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
}
