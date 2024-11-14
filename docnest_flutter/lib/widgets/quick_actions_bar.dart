// lib/widgets/quick_actions_bar.dart

import 'dart:io';
import 'dart:ui';
import 'package:docnest_flutter/screens/login_screen.dart';
import 'package:docnest_flutter/services/document_service.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select documents to share'),
            behavior: SnackBarBehavior.floating,
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error preparing files for sharing'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing documents: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handleShare(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePrint(BuildContext context) async {
    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      final selectedDocs = provider.selectedDocuments;

      if (selectedDocs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select documents to print'),
            behavior: SnackBarBehavior.floating,
          ),
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
              Text(
                  'Preparing ${selectedDocs.length} documents for printing...'),
            ],
          ),
        ),
      );

      // Create a PDF document
      final pdf = pw.Document();

      for (final doc in selectedDocs) {
        try {
          final response = await http.get(
            Uri.parse('${ApiConfig.documentsUrl}${doc.id}/download'),
            headers: ApiConfig.authHeaders(provider.token),
          );

          if (response.statusCode == 200) {
            // Add the document content to the PDF
            pdf.addPage(
              pw.Page(
                build: (context) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(doc.name,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.Text(doc.description ?? 'No description',
                        style: pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 16),
                    pw.Expanded(
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Text(
                          String.fromCharCodes(response.bodyBytes),
                          style: pw.TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } catch (e) {
          print('Error downloading document ${doc.name}: $e');
        }
      }

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        // Print the PDF
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
        );

        // Clear selection after printing
        provider.clearSelection();
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing documents: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _handlePrint(context),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleUpload(BuildContext context) async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const UploadDocumentDialog(),
      );

      if (result != null && context.mounted) {
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
                Text('Uploading document...'),
              ],
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              behavior: SnackBarBehavior.floating,
            ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading document: $e'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _handleUpload(context),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleAuthError(BuildContext context) async {
    await const FlutterSecureStorage().delete(key: 'auth_token');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          behavior: SnackBarBehavior.floating,
        ),
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
