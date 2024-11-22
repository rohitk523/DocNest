// lib/services/documents/editing_service.dart

import 'package:flutter/material.dart';
import '../../models/document.dart';
import '../../providers/document_provider.dart';
import '../../services/document_service.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/edit_document_dialog.dart';

class DocumentEditingService {
  static Future<void> editDocument({
    required BuildContext context,
    required Document document,
    required DocumentProvider provider,
  }) async {
    if (!provider.hasValidToken) {
      CustomSnackBar.showError(
        context: context,
        title: 'Log In to Edit',
        message: 'Please log in to edit documents',
      );
      return;
    }

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => EditDocumentDialog(document: document),
      );

      if (result != null && context.mounted) {
        // Show loading dialog
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

        // Update document
        final documentService = DocumentService(token: provider.token);
        final updatedDoc = await documentService.updateDocument(
          documentId: document.id,
          name: result['name'],
          description: result['description'],
          category: result['category'],
        );

        // Update provider state
        provider.updateDocument(updatedDoc);

        if (context.mounted) {
          // Dismiss loading dialog
          Navigator.of(context).pop();

          // Show success message
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Edited Successfully',
            message: 'Document edited successfully',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.of(context).pop();

        // Show error message and retry option
        CustomSnackBar.showError(
          context: context,
          title: 'Error Updating Document',
          message: 'Error updating document: $e',
          actionLabel: 'Retry',
          onAction: () => editDocument(
            context: context,
            document: document,
            provider: provider,
          ),
        );
      }
    }
  }

  static Future<void> updateDocumentCategory({
    required BuildContext context,
    required String documentId,
    required String newCategory,
    required DocumentProvider provider,
  }) async {
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
              Text('Updating category...'),
            ],
          ),
        ),
      );

      // Update category
      await provider.updateDocumentCategory(documentId, newCategory);

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.of(context).pop();

        // Show success message
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Category Updated',
          message: 'Document category updated successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.of(context).pop();

        // Show error message
        CustomSnackBar.showError(
          context: context,
          title: 'Error Updating Category',
          message: 'Error: $e',
          actionLabel: 'Retry',
          onAction: () => updateDocumentCategory(
            context: context,
            documentId: documentId,
            newCategory: newCategory,
            provider: provider,
          ),
        );
      }
    }
  }
}
