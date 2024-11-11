// lib/widgets/document_tile.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../services/document_service.dart';
import './edit_document_dialog.dart';

class DocumentTile extends StatelessWidget {
  final Document document;

  const DocumentTile({
    Key? key,
    required this.document,
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
        break;
    }
  }

  Future<void> _shareDocument(BuildContext context) async {
    try {
      final text = '''
Document: ${document.name}
Category: ${document.category}
Description: ${document.description}
Created: ${formatDate(document.createdAt)}
''';
      await Share.share(text, subject: document.name);
    } catch (e) {
      _showErrorSnackBar(context, 'Error sharing document: $e');
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
      if (document.filePath == null) {
        throw Exception('No file available for download');
      }

      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get the token from provider
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      final token = provider.token;

      // Construct download URL
      final downloadUrl = '${ApiConfig.documentsUrl}${document.id}/download';

      // Make the download request
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: ApiConfig.authHeaders(token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download file');
      }

      // Get the downloads directory
      final tempDir = await getTemporaryDirectory();
      final fileName = document.filePath!.split('/').last;
      final file = File('${tempDir.path}/$fileName');

      // Write the file
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        // Close progress dialog
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded: ${file.path}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Close progress dialog if open
        Navigator.pop(context);
        _showErrorSnackBar(context, 'Error downloading document: $e');
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
    final theme = Theme.of(context);

    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isSelected(document.id);
        final isSelectionMode = provider.isSelectionMode;

        return Dismissible(
          key: Key(document.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            final result = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Delete Document'),
                content:
                    Text('Are you sure you want to delete "${document.name}"?'),
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
            return result ?? false;
          },
          onDismissed: (_) async {
            try {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) => const PopScope(
                  // Changed from WillPopScope
                  canPop: false, // Changed from onWillPop
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
                Navigator.of(context).pop(); // Dismiss loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document deleted successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.of(context).pop(); // Dismiss loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting document: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.delete,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                      )
                    : Icon(
                        getCategoryIcon(document.category),
                        color: getCategoryColor(document.category),
                      ),
              ),
              title: Text(
                document.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (document.description.isNotEmpty) ...[
                    Text(
                      document.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            formatDate(document.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (document.fileSize != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              formatFileSize(document.fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      if (document.fileType != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              document.fileType!.split('/').last.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              trailing: isSelectionMode
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () => _handleEdit(context, provider),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: theme.colorScheme.primary),
                          onSelected: (action) =>
                              _handleMenuAction(context, action),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'info',
                              child: Row(
                                children: [
                                  Icon(Icons.info,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Info'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Share'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Download'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'print',
                              child: Row(
                                children: [
                                  Icon(Icons.print,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Print'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
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
              onLongPress: () {
                if (!isSelectionMode) {
                  provider.toggleSelection(document.id);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
