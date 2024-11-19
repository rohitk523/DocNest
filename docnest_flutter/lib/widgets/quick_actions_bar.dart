// lib/widgets/quick_actions_bar.dart

import 'dart:io';
import 'dart:ui';
import 'package:docnest_flutter/screens/login_screen.dart';
import 'package:docnest_flutter/services/document_service.dart';
import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import '../utils/formatters.dart';
import '../providers/document_provider.dart';
import './upload_dialog.dart';
import './search_widget.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

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

  Future<void> _handleShare(BuildContext context) async {
    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      final selectedDocs = provider.selectedDocuments;

      if (selectedDocs.isEmpty) {
        CustomSnackBar.showInfo(
          context: context,
          title: 'Select Documents',
          message: 'Please select documents to share',
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Preparing ${selectedDocs.length} documents for sharing...'),
            ],
          ),
        ),
      );

      // List to store temporary files
      final List<XFile> filesToShare = [];
      final tempDir = await getTemporaryDirectory();

      // Download each selected document
      for (final doc in selectedDocs) {
        try {
          final response = await http.get(
            Uri.parse('${ApiConfig.documentsUrl}${doc.id}/download'),
            headers: ApiConfig.authHeaders(provider.token),
          );

          if (response.statusCode == 200) {
            // Get filename from Content-Disposition header or use document name
            final contentDisposition = response.headers['content-disposition'];
            String filename = '';
            if (contentDisposition != null &&
                contentDisposition.contains('filename=')) {
              filename =
                  contentDisposition.split('filename=')[1].replaceAll('"', '');
            } else {
              filename = doc.name;
              if (!filename.contains('.') && doc.fileType != null) {
                filename = '$filename.${doc.fileType!.split('/').last}';
              }
            }

            // Create and save temporary file
            final tempFile = File('${tempDir.path}/$filename');
            await tempFile.writeAsBytes(response.bodyBytes);
            filesToShare.add(XFile(tempFile.path));
          }
        } catch (e) {
          print('Error downloading document ${doc.name}: $e');
        }
      }

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        if (filesToShare.isEmpty) {
          CustomSnackBar.showError(
            context: context,
            title: 'Error Preparing Files',
            message: 'Error preparing files for sharing',
          );
          return;
        }

        // Create share text
        final shareText = selectedDocs.map((doc) => '''
📄 ${doc.name}
📁 Category: ${doc.category}
📝 Description: ${doc.description ?? 'No description'}
📅 Created: ${formatDate(doc.createdAt)}
📦 Size: ${formatFileSize(doc.fileSize)}''').join('\n\n');

        // Share files and text
        await Share.shareXFiles(
          filesToShare,
          text: shareText,
          subject: 'Shared Documents (${selectedDocs.length})',
        );

        // Clean up temporary files after a delay
        Future.delayed(const Duration(minutes: 1), () {
          for (var file in filesToShare) {
            try {
              File(file.path).deleteSync();
            } catch (e) {
              print('Error deleting temporary file: $e');
            }
          }
        });

        // Clear selection after sharing
        provider.clearSelection();
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.pop(context);

        CustomSnackBar.showError(
          context: context,
          title: 'Error Sharing Documents',
          message: 'Error: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => _handleShare(context),
        );
      }
    }
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

  Future<void> _handlePrint(BuildContext context) async {
    try {
      // Implement print logic here
      _showSnackBar(context, 'Print feature coming soon');
    } catch (e) {
      _showErrorSnackBar(context, 'Error printing document: $e');
    }
  }

  // In QuickActionsBar class

  Future<void> _handleUpload(BuildContext context) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const UploadDocumentDialog(),
      );

      if (result != null && context.mounted) {
        // Show loading indicator with fixed width and better constraints
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).dialogBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Uploading document...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        final documentService =
            DocumentService(token: context.read<DocumentProvider>().token);
        final uploadedDoc = await documentService.uploadDocument(
          name: result['name'],
          description: result['description'],
          category: result['category'],
          file: result['file'],
        );

        if (context.mounted) {
          // Dismiss loading dialog
          Navigator.pop(context);

          context.read<DocumentProvider>().addDocument(uploadedDoc);

          CustomSnackBar.showSuccess(
            context: context,
            title: 'Upload Successful',
            message: 'Document uploaded successfully',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.popUntil(context, (route) => route.isFirst);

        if (e.toString().contains('Could not validate credentials')) {
          _handleAuthError(context);
        } else {
          CustomSnackBar.showError(
            context: context,
            title: 'Error Uploading Document',
            message: 'Error: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: () => _handleUpload(context),
          );
        }
      }
    }
  }

  Future<void> _handleAuthError(BuildContext context) async {
    await const FlutterSecureStorage().delete(key: 'auth_token');
    if (context.mounted) {
      CustomSnackBar.showInfo(
        context: context,
        title: 'Session Expired',
        message: 'Please log in again',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
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
                      TextButton(
                        onPressed: () => provider.clearSelection(),
                        child: const Text('Clear'),
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
