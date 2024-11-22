// lib/widgets/quick_actions_bar.dart

import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/documents/deletion_service.dart';
import '../services/documents/sharing_service.dart';
import '../services/documents/uploading_service.dart';
import '../providers/document_provider.dart';
import 'search_widget.dart';

class QuickActionsBar extends StatelessWidget {
  const QuickActionsBar({super.key});

  void _toggleSelectionMode(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    if (provider.isSelectionMode) {
      provider.clearSelection();
    } else {
      provider.startSelection();
    }
  }

  void _handleSearch(BuildContext context) {
    showDocumentSearch(context);
  }

  void _showSnackBar(BuildContext context, String message) {
    CustomSnackBar.showInfo(
      context: context,
      title: 'Information',
      message: message,
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    CustomSnackBar.showError(
      context: context,
      title: 'Error',
      message: message,
    );
  }

  Future<void> _handleShare(BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    await DocumentSharingService.shareMultipleDocuments(
      context,
      provider.selectedDocuments,
      provider.token,
    );
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      // Implement print logic here
      _showSnackBar(context, 'Print feature coming soon');
    } catch (e) {
      _showErrorSnackBar(context, 'Error printing document: $e');
    }
  }

  Future<void> _handleUpload(BuildContext context) async {
    await DocumentUploadingService.showUploadDialog(context);
  }

  Future<void> _handleMultipleDelete(
      BuildContext context, DocumentProvider provider) async {
    await DocumentDeletionService.deleteMultipleDocuments(
      context: context,
      documents: provider.selectedDocuments,
      provider: provider,
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

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
              color:
                  isEnabled ? theme.colorScheme.primary : theme.disabledColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<DocumentProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isSelectionMode;
        final selectedCount = provider.selectedCount;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$selectedCount selected',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => provider.selectAll(),
                            icon: const Icon(Icons.select_all, size: 20),
                            label: const Text('Select All'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: selectedCount > 0
                                ? () => _handleMultipleDelete(context, provider)
                                : null,
                            icon: const Icon(Icons.delete_outline, size: 20),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => provider.clearSelection(),
                            icon: const Icon(Icons.clear_all, size: 20),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: isSelectionMode
                    ? [
                        _buildActionButton(
                          context: context,
                          icon: Icons.print,
                          label: 'Print',
                          onTap: selectedCount > 0
                              ? () => _handlePrint(context)
                              : null,
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.search,
                          label: 'Search',
                          onTap: () => _handleSearch(context),
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.share,
                          label: 'Share',
                          onTap: selectedCount > 0
                              ? () => _handleShare(context)
                              : null,
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.close,
                          label: 'Cancel',
                          onTap: () => _toggleSelectionMode(context),
                        ),
                      ]
                    : [
                        _buildActionButton(
                          context: context,
                          icon: Icons.upload_file,
                          label: 'Upload',
                          onTap: () => _handleUpload(context),
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.search,
                          label: 'Search',
                          onTap: () => _handleSearch(context),
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.share,
                          label: 'Share',
                          onTap: selectedCount > 0
                              ? () => _handleShare(context)
                              : null,
                        ),
                        _buildActionButton(
                          context: context,
                          icon: Icons.checklist,
                          label: 'Select',
                          onTap: () => _toggleSelectionMode(context),
                        ),
                      ],
              ),
            ],
          ),
        );
      },
    );
  }
}
