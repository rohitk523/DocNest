import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import '../../models/document.dart';
import '../../utils/document_filename_utils.dart';
import 'cache_service.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_snackbar.dart';

class DocumentDownloadService {
  static Future<void> downloadDocument(
    BuildContext context,
    Document document,
    String token,
  ) async {
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

      // Get proper filename
      final filename = DocumentFilenameUtils.getProperFilename(document);
      final cacheService = CacheService();

      // Try to get from cache first
      File? cachedFile = await cacheService.getCachedDocumentByName(filename);

      if (cachedFile == null || !await cachedFile.exists()) {
        // If not cached, download from server
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
          headers: ApiConfig.authHeaders(token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to download document');
        }

        // Save to downloads directory
        if (await Permission.storage.request().isGranted) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          final file = File('${downloadDir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes);

          // Cache for future use
          await cacheService.cacheDocumentWithName(
              filename, response.bodyBytes);
        } else {
          throw Exception('Storage permission required');
        }
      } else {
        // If file exists in cache, copy it to downloads
        final downloadDir = Directory('/storage/emulated/0/Download');
        final file = File('${downloadDir.path}/$filename');
        await cachedFile.copy(file.path);
      }

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Download Complete',
          message: 'File saved to Downloads folder:\n$filename',
        );
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
