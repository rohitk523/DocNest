import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../widgets/edit_document_dialog.dart';
import '../services/document_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import 'dart:convert';

class DocumentTile extends StatelessWidget {
  final Document document;
  final bool isDragging;

  const DocumentTile({
    Key? key,
    required this.document,
    this.isDragging = false,
  }) : super(key: key);

  Future<void> _handleEdit(
      BuildContext context, DocumentProvider provider) async {
    if (!provider.hasValidToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to edit documents'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => EditDocumentDialog(document: document),
      );

      if (result != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Updating document...'),
              ],
            ),
          ),
        );

        final documentService = DocumentService(token: provider.token);
        final updatedDoc = await documentService.updateDocument(
          documentId: document.id,
          name: result['name'],
          description: result['description'],
          category: result['category'],
        );

        provider.updateDocument(updatedDoc);

        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document updated successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog if showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating document: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleEdit(context, provider),
            ),
          ),
        );
      }
    }
  }

  void _handleMenuAction(BuildContext context, String action) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);

    switch (action) {
      case 'info':
        await _showMetadata(context);
        break;
      case 'share':
        await _shareDocument(context);
        break;
      case 'download':
        await _downloadDocument(context);
        break;
      case 'print':
        await _printDocument(context);
        break;
      case 'delete':
        await _deleteDocument(context, provider);
      case 'edit':
        await _handleEdit(context, provider);
        break;
    }
  }

  Future<void> _shareDocument(BuildContext context) async {
    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);

      // Show loading indicator
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

      // Get share information
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}${document.id}/share'),
        headers: ApiConfig.authHeaders(provider.token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get share information');
      }

      final shareInfo = json.decode(response.body);

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        // Create share text with metadata and download link
        final shareText = '''
Document: ${shareInfo['name']}
Category: ${shareInfo['category']}
Description: ${shareInfo['description']}
Type: ${shareInfo['file_type'] ?? 'N/A'}
Size: ${formatFileSize(shareInfo['file_size'])}
Created: ${shareInfo['created_at']}
By: ${shareInfo['metadata']['owner']}

${shareInfo['download_url'] != null ? 'Download link (expires in 1 hour):\n${shareInfo['download_url']}' : ''}
''';

        // Share the document information
        await Share.share(
          shareText.trim(),
          subject: shareInfo['name'],
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing document: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _shareDocument(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _printDocument(BuildContext context) async {
    try {
      // Implement print logic here
      _showSnackBar(context, 'Print feature coming soon');
    } catch (e) {
      _showErrorSnackBar(context, 'Error printing document: $e');
    }
  }

  Future<void> _showMetadata(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Document Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _metadataRow('Name', document.name),
              _metadataRow('Category', document.category),
              _metadataRow('Description', document.description),
              _metadataRow('File Size', formatFileSize(document.fileSize)),
              _metadataRow('File Type', document.fileType ?? 'N/A'),
              _metadataRow('Created', formatDateDetailed(document.createdAt)),
              _metadataRow('Modified', formatDateDetailed(document.modifiedAt)),
              _metadataRow('Version', document.version.toString()),
              _metadataRow('Shared', document.isShared ? 'Yes' : 'No'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _metadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(BuildContext context) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission is required to download files');
        }
      }
      try {
        final provider = Provider.of<DocumentProvider>(context, listen: false);

        // Show download progress dialog
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

        // Get the downloads directory
        Directory? downloadDir;
        if (Platform.isAndroid) {
          // For Android, use external storage directory
          final directories = await getExternalStorageDirectories();
          if (directories != null && directories.isNotEmpty) {
            downloadDir = directories.first;
          }
        } else {
          // For iOS, use documents directory
          downloadDir = await getApplicationDocumentsDirectory();
        }

        if (downloadDir == null) {
          throw Exception('Could not access download directory');
        }

        // Create a dedicated downloads folder
        final downloadsFolder = Directory('${downloadDir.path}/Downloads');
        if (!await downloadsFolder.exists()) {
          await downloadsFolder.create(recursive: true);
        }

        // Make download request
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
          headers: ApiConfig.authHeaders(provider.token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to download document');
        }

        // Get the filename from the document name
        String filename = document.name;
        if (!filename.contains('.') && document.fileType != null) {
          filename = '$filename.${document.fileType!.split('/').last}';
        }

        // Ensure filename is safe for file system
        filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

        // Create the full file path
        final filePath = '${downloadsFolder.path}/$filename';

        // Write the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          // Dismiss loading dialog
          Navigator.pop(context);

          // Show success message with file location
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Document downloaded: $filename'),
                  Text(
                    'Location: ${downloadsFolder.path}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open Folder',
                onPressed: () async {
                  // Add open_file package to pubspec.yaml first:
                  // open_file: ^3.3.2
                  try {
                    await OpenFile.open(downloadsFolder.path);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open folder: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          // Dismiss loading dialog if showing
          Navigator.pop(context);

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading document: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _downloadDocument(context),
              ),
            ),
          );
        }
      }

      // Rest of the download code...
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error in permission: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _downloadDocument(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(
      BuildContext context, DocumentProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const PopScope(
            canPop: false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting document...'),
                ],
              ),
            ),
          ),
        );

        await provider.removeDocument(document.id);

        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting document: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _deleteDocument(context, provider),
              ),
            ),
          );
        }
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isSelected(document.id);
        final isSelectionMode = provider.isSelectionMode;
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: getCategoryColor(document.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => provider.toggleSelection(document.id),
                      activeColor: theme.colorScheme.primary,
                    )
                  : Icon(
                      getCategoryIcon(document.category),
                      color: getCategoryColor(document.category),
                    ),
            ),
            title: Text(
              document.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (document.description.isNotEmpty) ...[
                  Text(document.description),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(document.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    if (document.fileType != null) ...[
                      Icon(Icons.description,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        document.fileType!.split('/').last.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: theme.colorScheme.primary),
                    onSelected: (action) => _handleMenuAction(context, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 8),
                            Text('Info'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Download'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(document.id);
              }
            },
          ),
        );
      },
    );
  }
}
