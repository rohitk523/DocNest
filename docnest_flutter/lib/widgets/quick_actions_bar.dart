// lib/widgets/quick_actions_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/document_provider.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'document_search.dart';
import 'upload_dialog.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  void _toggleSelectionMode(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    if (provider.isSelectionMode) {
      provider.clearSelection();
    } else {
      // Start selection mode with the first document selected
      if (provider.documents.isNotEmpty) {
        provider.toggleSelection(provider.documents.first.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isSelectionMode;
        final selectedCount = provider.selectedCount;
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : theme.scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? Colors.black26
                    : Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelectionMode) _buildSelectionBar(context, provider),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context,
                    Icons.upload_file,
                    'Upload',
                    () => _handleUpload(context),
                  ),
                  _buildActionButton(
                    context,
                    Icons.search,
                    'Search',
                    () => _handleSearch(context),
                  ),
                  _buildActionButton(
                    context,
                    Icons.share,
                    'Share${selectedCount > 0 ? " ($selectedCount)" : ""}',
                    selectedCount > 0 ? () => _handleShare(context) : null,
                  ),
                  _buildActionButton(
                    context,
                    isSelectionMode ? Icons.close : Icons.checklist,
                    isSelectionMode ? 'Cancel' : 'Select',
                    () => _toggleSelectionMode(
                        context), // Use the new method here
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionBar(BuildContext context, DocumentProvider provider) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${provider.selectedCount} selected',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => provider.selectAll(),
                child: Text(
                  'Select All',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: provider.selectedCount > 0
                    ? () => _handleDelete(context, provider)
                    : null,
                child: Text(
                  'Delete',
                  style: TextStyle(
                    color: theme.brightness == Brightness.dark
                        ? Colors.redAccent
                        : Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    // Use colorScheme for better dark mode support
    final iconColor = isEnabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.38);

    final textColor = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withOpacity(0.38);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpload(BuildContext context) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UploadDocumentDialog(),
    );

    if (result != null && context.mounted) {
      final provider = context.read<DocumentProvider>();
      try {
        // Handle the upload result
        // This would typically involve calling your document service
        // and then updating the provider
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSearch(BuildContext context) async {
    final provider = context.read<DocumentProvider>();
    if (provider.isSelectionMode) {
      provider.clearSelection();
    }

    final Document? result = await showDialog<Document>(
      context: context,
      builder: (BuildContext context) => const SearchDialog(),
    );

    if (result != null && context.mounted) {
      // Handle the selected document
      provider.clearSelection();
      provider.toggleSelection(result.id);

      // Show a snackbar to confirm selection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected document: ${result.name}'),
          action: SnackBarAction(
            label: 'Clear',
            onPressed: () => provider.clearSelection(),
          ),
        ),
      );
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    final provider = context.read<DocumentProvider>();
    if (provider.selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select documents to share')),
      );
      return;
    }

    try {
      final selectedDocs = provider.selectedDocuments;

      // Create a temporary directory to store files for sharing
      final tempDir = await getTemporaryDirectory();
      final shareDir = await Directory('${tempDir.path}/share').create();

      // List to store paths of files to share
      List<String> filePaths = [];
      List<XFile> shareFiles = [];

      // Prepare text content for documents without files
      String textContent = 'Shared Documents:\n\n';

      for (var doc in selectedDocs) {
        if (doc.filePath != null && File(doc.filePath!).existsSync()) {
          // Copy file to temp directory with a clean name
          final fileName = '${doc.name}.${doc.filePath!.split('.').last}';
          final tempFile = File('${shareDir.path}/$fileName');
          await File(doc.filePath!).copy(tempFile.path);
          filePaths.add(tempFile.path);
          shareFiles.add(XFile(tempFile.path));
        }

        // Add document details to text content
        textContent += '''
Document: ${doc.name}
Category: ${doc.category}
Description: ${doc.description}
Created: ${formatDate(doc.createdAt)}
Modified: ${formatDate(doc.modifiedAt)}
-------------------
''';
      }

      if (shareFiles.isNotEmpty) {
        // Share files if available
        await Share.shareXFiles(
          shareFiles,
          text: textContent,
          subject: 'Shared Documents from DocNest',
        );
      } else {
        // Share only text content if no files
        await Share.share(
          textContent,
          subject: 'Shared Documents from DocNest',
        );
      }

      // Clean up temporary files
      for (var path in filePaths) {
        try {
          await File(path).delete();
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
      }
      await shareDir.delete(recursive: true);

      provider.clearSelection();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents shared successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(
      BuildContext context, DocumentProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Selected Documents'),
          content: Text(
              'Are you sure you want to delete ${provider.selectedCount} selected documents?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await provider.removeSelectedDocuments();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected documents deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting documents: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
