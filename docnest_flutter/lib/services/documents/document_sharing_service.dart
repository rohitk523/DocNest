// lib/services/document_sharing_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/document.dart';
import 'cache_service.dart';
import '../../config/api_config.dart';
import '../../utils/formatters.dart';
import '../../widgets/custom_snackbar.dart';

class DocumentSharingService {
  static String _getFileExtension(String? mimeType) {
    return switch (mimeType) {
      'application/pdf' => '.pdf',
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'application/msword' => '.doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        '.docx',
      _ => '',
    };
  }

  static Future<void> shareDocument(
      BuildContext context, Document document, String token) async {
    try {
      final cacheService = CacheService();

      // Generate proper filename with extension
      String filename = document.name;
      if (!filename.contains('.') && document.fileType != null) {
        final extension = _getFileExtension(document.fileType);
        filename = '$filename$extension';
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparing document for sharing...'),
              ],
            ),
          ),
        );
      }

      // Try to get cached file first
      File? cachedFile = await cacheService.getCachedDocumentByName(filename);

      if (cachedFile == null || !await cachedFile.exists()) {
        // If not cached, download and cache
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
          headers: ApiConfig.authHeaders(token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to download document for sharing');
        }

        // Get temporary directory for sharing
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename');

        // Write file to temporary directory
        await tempFile.writeAsBytes(response.bodyBytes);

        // Cache the file for future use
        await cacheService.cacheDocumentWithName(filename, response.bodyBytes);
        cachedFile = tempFile;
      }

      if (cachedFile != null && context.mounted) {
        // Create share text with document details
        final shareText = '''
📄 ${document.name}
📁 Category: ${document.category}
📝 Description: ${document.description ?? 'No description'}
📅 Created: ${formatDate(document.createdAt)}
📦 Size: ${formatFileSize(document.fileSize)}
''';

        // Dismiss loading dialog
        Navigator.pop(context);

        // Share file and text
        await Share.shareXFiles(
          [XFile(cachedFile.path)],
          text: shareText,
          subject: document.name,
        );
      }
    } catch (e) {
      print('Share error: $e');
      if (context.mounted) {
        // Dismiss loading dialog if showing
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        CustomSnackBar.showError(
          context: context,
          title: 'Sharing Failed',
          message: 'Error sharing document: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => shareDocument(context, document, token),
        );
      }
    }
  }

  static Future<void> shareMultipleDocuments(
      BuildContext context, List<Document> documents, String token) async {
    try {
      if (documents.isEmpty) {
        CustomSnackBar.showInfo(
          context: context,
          title: 'Select Documents',
          message: 'Please select documents to share',
        );
        return;
      }

      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Preparing ${documents.length} documents for sharing...'),
              ],
            ),
          ),
        );
      }

      final cacheService = CacheService();
      final List<XFile> filesToShare = [];
      final tempDir = await getTemporaryDirectory();

      // Process each document
      for (final doc in documents) {
        try {
          // Generate proper filename with extension
          String filename = doc.name;
          if (!filename.contains('.') && doc.fileType != null) {
            final extension = _getFileExtension(doc.fileType);
            filename = '$filename$extension';
          }

          // Try cached file first
          File? cachedFile =
              await cacheService.getCachedDocumentByName(filename);

          if (cachedFile == null || !await cachedFile.exists()) {
            // Download if not cached
            final response = await http.get(
              Uri.parse('${ApiConfig.documentsUrl}${doc.id}/download'),
              headers: ApiConfig.authHeaders(token),
            );

            if (response.statusCode == 200) {
              final tempFile = File('${tempDir.path}/$filename');
              await tempFile.writeAsBytes(response.bodyBytes);

              // Cache for future use
              await cacheService.cacheDocumentWithName(
                  filename, response.bodyBytes);
              cachedFile = tempFile;
            }
          }

          if (cachedFile != null) {
            filesToShare.add(XFile(cachedFile.path));
          }
        } catch (e) {
          print('Error processing document ${doc.name}: $e');
        }
      }

      if (filesToShare.isNotEmpty && context.mounted) {
        // Create share text for all documents
        final shareText = documents.map((doc) => '''
📄 ${doc.name}
📁 Category: ${doc.category}
📝 Description: ${doc.description ?? 'No description'}
📅 Created: ${formatDate(doc.createdAt)}
📦 Size: ${formatFileSize(doc.fileSize)}''').join('\n\n');

        // Dismiss loading dialog
        Navigator.pop(context);

        // Share all files and text
        await Share.shareXFiles(
          filesToShare,
          text: shareText,
          subject: 'Shared Documents (${documents.length})',
        );
      } else {
        throw Exception('No files could be prepared for sharing');
      }
    } catch (e) {
      print('Share error: $e');
      if (context.mounted) {
        // Dismiss loading dialog if showing
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        CustomSnackBar.showError(
          context: context,
          title: 'Sharing Failed',
          message: 'Error sharing documents: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => shareMultipleDocuments(context, documents, token),
        );
      }
    }
  }
}
