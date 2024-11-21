// lib/services/document_deletion_service.dart

import 'package:flutter/material.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../widgets/custom_snackbar.dart';
import '../../theme/app_theme.dart';

class DocumentDeletionService {
  static Future<void> deleteSingleDocument({
    required BuildContext context,
    required Document document,
    required DocumentProvider provider,
  }) async {
    // Show confirmation dialog
    final confirmed = await _showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Document',
      content: 'Are you sure you want to delete "${document.name}"?',
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        _showDeletionLoadingDialog(context);

        // Delete document
        await provider.removeDocument(document.id);

        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show success message
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Document Deleted',
            message: 'Document deleted successfully',
          );
        }
      } catch (e) {
        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show error message
          CustomSnackBar.showError(
            context: context,
            title: 'Delete Error',
            message: 'Error deleting document: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: () => deleteSingleDocument(
              context: context,
              document: document,
              provider: provider,
            ),
          );
        }
      }
    }
  }

  static Future<void> deleteMultipleDocuments({
    required BuildContext context,
    required List<Document> documents,
    required DocumentProvider provider,
  }) async {
    // Show confirmation dialog
    final confirmed = await _showDeleteConfirmationDialog(
      context: context,
      title: 'Delete Documents',
      content:
          'Are you sure you want to delete ${documents.length} document${documents.length > 1 ? 's' : ''}?',
    );

    if (confirmed == true && context.mounted) {
      try {
        // Show loading indicator
        _showDeletionLoadingDialog(
          context,
          message:
              'Deleting ${documents.length} document${documents.length > 1 ? 's' : ''}...',
        );

        // Delete each document
        for (final doc in documents) {
          await provider.removeDocument(doc.id);
        }

        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show success message
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Documents Deleted',
            message:
                '${documents.length} document${documents.length > 1 ? 's' : ''} deleted successfully',
          );

          // Clear selection after deletion
          provider.clearSelection();
        }
      } catch (e) {
        if (context.mounted) {
          // Dismiss loading indicator
          Navigator.of(context).pop();

          // Show error message
          CustomSnackBar.showError(
            context: context,
            title: 'Delete Error',
            message: 'Error deleting documents: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: () => deleteMultipleDocuments(
              context: context,
              documents: documents,
              provider: provider,
            ),
          );
        }
      }
    }
  }

  static Future<bool?> _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: AppTextStyles.headline2.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
        ),
        content: Text(
          content,
          style: AppTextStyles.body1.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.dialogBackgroundColor,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            child: Text(
              'Cancel',
              style: AppTextStyles.button,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(
              'Delete',
              style: AppTextStyles.button.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showDeletionLoadingDialog(BuildContext context,
      {String message = 'Deleting document...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
