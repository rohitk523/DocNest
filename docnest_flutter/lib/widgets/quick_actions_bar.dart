import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/document_provider.dart';
import 'document_search.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isSelectionMode;
        final selectedCount = provider.selectedCount;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
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
                    () => _handleShare(context),
                    isEnabled: selectedCount > 0,
                  ),
                  _buildActionButton(
                    context,
                    isSelectionMode ? Icons.close : Icons.checklist,
                    isSelectionMode ? 'Cancel' : 'Select',
                    () => _handleSelectionMode(context),
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
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${provider.selectedCount} selected',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => provider.selectAllDocuments(),
                child: const Text('Select All'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _handleDelete(context),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
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
    VoidCallback onTap, {
    bool isEnabled = true,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isEnabled ? theme.primaryColor : theme.disabledColor,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 12,
              color: isEnabled
                  ? theme.textTheme.bodyMedium?.color
                  : theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpload(BuildContext context) async {
    // Implement file upload functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload functionality coming soon')),
    );
  }

  void _handleSearch(BuildContext context) async {
    final provider = context.read<DocumentProvider>();
    if (provider.isSelectionMode) {
      provider.toggleSelectionMode();
    }

    final documents = provider.documents;
    final Document? result = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SearchDialog(documents: documents);
      },
    );

    if (result != null) {
      // Handle the selected document
      // For example:
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => DocumentDetailScreen(document: result),
      //   ),
      // );
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
      final selectedDocs = provider.selectedDocumentObjects;

      // For sharing text content
      String shareText = selectedDocs.map((doc) => '''
Document: ${doc.name}
Category: ${doc.category}
Content: ${doc.content}
''').join('\n---\n');

      // For sharing files (if path is available)
      List<String> filePaths = selectedDocs
          .where((doc) => doc.path != null)
          .map((doc) => doc.path!)
          .toList();

      if (filePaths.isNotEmpty) {
        // Share files if available
        await Share.shareXFiles(
          filePaths.map((path) => XFile(path)).toList(),
          text: 'Sharing ${filePaths.length} documents',
        );
      } else {
        // Share text content if no files
        await Share.share(
          shareText,
          subject: 'Shared Documents (${selectedDocs.length})',
        );
      }

      // Mark documents as shared
      provider.markDocumentsAsShared(provider.selectedDocuments.toList());

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documents shared successfully')),
        );
      }

      // Clear selection after sharing
      provider.clearSelection();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing documents: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        debugPrint('Sharing error: $e');
      }
    }
  }

  void _handleSelectionMode(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    provider.toggleSelectionMode();
  }

  Future<void> _handleDelete(BuildContext context) async {
    final provider = context.read<DocumentProvider>();

    if (provider.selectedCount == 0) return;

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
      provider.removeSelectedDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected documents deleted')),
      );
    }
  }
}
