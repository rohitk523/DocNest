// lib/widgets/document_tile.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DocumentTile extends StatelessWidget {
  final Document document;

  const DocumentTile({
    Key? key,
    required this.document,
  }) : super(key: key);

  void _handleMenuAction(BuildContext context, String action) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);

    switch (action) {
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

  Future<void> _downloadDocument(BuildContext context) async {
    try {
      if (document.filePath != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = document.filePath!.split('/').last;
        final file = File('${tempDir.path}/$fileName');

        // Download logic here using your DocumentService
        _showSnackBar(context, 'Download feature coming soon');
      } else {
        throw Exception('No file available for download');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error downloading document: $e');
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
          builder: (BuildContext context) => const Center(
            child: CircularProgressIndicator(),
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
              content: Text('Error deleting document: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
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

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
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
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(document.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten, size: 14, color: Colors.grey[400]),
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
              ],
            ),
            trailing: isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: theme.colorScheme.primary),
                    onSelected: (action) => _handleMenuAction(context, action),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share,
                                size: 20, color: theme.colorScheme.primary),
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
                                size: 20, color: theme.colorScheme.primary),
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
                                size: 20, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Print'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
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
            onLongPress: () {
              if (!isSelectionMode) {
                provider.toggleSelection(document.id);
              }
            },
          ),
        );
      },
    );
  }
}
