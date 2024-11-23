// lib/services/document_sharing_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/document.dart';
import '../../utils/document_filename_utils.dart';
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

  static Future<void> openDocument(
    BuildContext context,
    Document document,
    String token,
  ) async {
    final cacheService = CacheService();
    final filename = DocumentFilenameUtils.getProperFilename(document);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening document...'),
            ],
          ),
        ),
      );

      // Try to get cached file
      File? cachedFile = await cacheService.getCachedDocumentByName(filename);

      if (cachedFile == null || !await cachedFile.exists()) {
        // If not cached, download and cache
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
          headers: ApiConfig.authHeaders(token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch document file');
        }

        await cacheService.cacheDocumentWithName(filename, response.bodyBytes);
        cachedFile = await cacheService.getCachedDocumentByName(filename);
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
      }

      if (cachedFile != null) {
        await OpenFilex.open(cachedFile.path, type: document.fileType);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        CustomSnackBar.showError(
          context: context,
          title: 'Error opening document',
          message: 'Error: ${e.toString()}',
        );
      }
    }
  }

  static Future<void> shareDocument(
    BuildContext context,
    Document document,
    String token,
  ) async {
    try {
      final cacheService = CacheService();

      // Get proper filename with extension
      final extension = _getFileExtension(document.fileType);
      final filename =
          document.name + (document.name.endsWith(extension) ? '' : extension);

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

        // Create temp file with proper extension
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
📁 Category: ${getCategoryDisplayName(document.category)}
📝 Description: ${document.description ?? 'No description'}
📅 Created: ${formatDate(document.createdAt)}
📦 Size: ${formatFileSize(document.fileSize)}
📎 File Type: ${_getFileTypeDisplay(document.fileType)}
''';

        // Dismiss loading dialog
        Navigator.pop(context);

        // Create XFile with proper mime type
        final shareFile =
            XFile(cachedFile.path, mimeType: document.fileType, name: filename);

        // Share file and text
        await Share.shareXFiles(
          [shareFile],
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
    BuildContext context,
    List<Document> documents,
    String token,
  ) async {
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
          final extension = _getFileExtension(doc.fileType);
          final filename =
              doc.name + (doc.name.endsWith(extension) ? '' : extension);

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
            // Create XFile with proper mime type
            filesToShare.add(
                XFile(cachedFile.path, mimeType: doc.fileType, name: filename));
          }
        } catch (e) {
          print('Error processing document ${doc.name}: $e');
        }
      }

      if (filesToShare.isNotEmpty && context.mounted) {
        // Create share text for all documents
        final shareText = documents.map((doc) => '''
📄 ${doc.name}
📁 Category: ${getCategoryDisplayName(doc.category)}
📝 Description: ${doc.description ?? 'No description'}
📅 Created: ${formatDate(doc.createdAt)}
📦 Size: ${formatFileSize(doc.fileSize)}
📎 File Type: ${_getFileTypeDisplay(doc.fileType)}''').join('\n\n');

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

  static String _getFileTypeDisplay(String? mimeType) {
    return switch (mimeType) {
      'application/pdf' => 'PDF Document',
      'image/jpeg' => 'JPEG Image',
      'image/png' => 'PNG Image',
      'application/msword' => 'Word Document',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' =>
        'Word Document',
      _ => 'Unknown Type',
    };
  }
}
