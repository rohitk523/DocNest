import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../models/document.dart';
import 'cache_service.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';

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

      final cacheService = CacheService();
      final fileName = document.name;

      // Try to get cached file first
      File? cachedFile = await cacheService.getCachedDocumentByName(fileName);

      if (cachedFile == null || !await cachedFile.exists()) {
        // If not cached, download and cache
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
          headers: ApiConfig.authHeaders(token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to download document');
        }

        // Get temporary directory for storing the file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');

        // Write file to temporary directory
        await tempFile.writeAsBytes(response.bodyBytes);

        // Cache the file for future use
        await cacheService.cacheDocumentWithName(fileName, response.bodyBytes);
        cachedFile = tempFile;
      }

      if (context.mounted) {
        // Dismiss the loading dialog
        Navigator.pop(context);

        // Show a success message
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Document Downloaded',
          message: 'The document has been downloaded successfully.',
        );
      }
    } catch (e) {
      print('Download error: $e');
      if (context.mounted) {
        // Dismiss the loading dialog
        Navigator.pop(context);

        // Show an error message
        CustomSnackBar.showError(
          context: context,
          title: 'Error Downloading Document',
          message: 'Error: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => downloadDocument(context, document, token),
        );
      }
    }
  }
}
