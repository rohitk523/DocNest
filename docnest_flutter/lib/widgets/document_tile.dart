import 'package:docnest_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../widgets/edit_document_dialog.dart';
import '../services/document_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../widgets/document_preview.dart';

class DocumentTileClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    // Adjustable values
    const double wedgeWidth = 120.0; // Total width of the wedge
    const double flatBottomWidth = 40.0; // Width of the flat bottom
    const double wedgeHeight = 13.0; // Height of the wedge
    const double cornerRadius = 20.0; // Corner radius of the main container

    // Calculate center positionr
    final center = size.width / 2;

    // Start from top-left with rounded corner
    path.moveTo(cornerRadius, 0);

    // Line to start of left wedge
    path.lineTo(center - wedgeWidth / 2, 0);

    // Left slant of wedge
    path.lineTo(center - flatBottomWidth / 2, wedgeHeight);

    // Flat bottom of wedge
    path.lineTo(center + flatBottomWidth / 2, wedgeHeight);

    // Right slant of wedge
    path.lineTo(center + wedgeWidth / 2, 0);

    // Line to top-right corner
    path.lineTo(size.width - cornerRadius, 0);

    // Add rounded corners
    // Top right corner
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Right side line
    path.lineTo(size.width, size.height - cornerRadius);

    // Bottom right corner
    path.quadraticBezierTo(
        size.width, size.height, size.width - cornerRadius, size.height);

    // Bottom line
    path.lineTo(cornerRadius, size.height);

    // Bottom left corner
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // Left side line
    path.lineTo(0, cornerRadius);

    // Top left corner
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

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
              Text('Preparing document for sharing...'),
            ],
          ),
        ),
      );

      // Download the file first
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
        headers: ApiConfig.authHeaders(provider.token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download document for sharing');
      }

      // Get filename from Content-Disposition header or document name
      final contentDisposition = response.headers['content-disposition'];
      String filename = '';
      if (contentDisposition != null &&
          contentDisposition.contains('filename=')) {
        filename = contentDisposition.split('filename=')[1].replaceAll('"', '');
      } else {
        filename = document.name;
        if (!filename.contains('.') && document.fileType != null) {
          filename = '$filename.${document.fileType!.split('/').last}';
        }
      }

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        // Share the file
        final files = [tempFile.path];
        final text = '''
Document: ${document.name}
Category: ${document.category}
Description: ${document.description ?? 'No description'}
Size: ${formatFileSize(document.fileSize)}
''';

        await Share.shareXFiles(
          files.map((path) => XFile(path)).toList(),
          text: text,
          subject: document.name,
        );

        // Clean up temp file after a delay
        Future.delayed(const Duration(minutes: 1), () {
          try {
            if (tempFile.existsSync()) {
              tempFile.deleteSync();
            }
          } catch (e) {
            print('Error cleaning up temp file: $e');
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog
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
      // Request necessary permissions
      if (Platform.isAndroid) {
        if (await Permission.storage.request().isGranted) {
          // Permission granted
        } else {
          throw Exception('Storage permission is required to download files');
        }
      }

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

      final provider = Provider.of<DocumentProvider>(context, listen: false);

      // Make download request
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}${document.id}/download'),
        headers: ApiConfig.authHeaders(provider.token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download document');
      }

      // Get filename from Content-Disposition header
      final contentDisposition = response.headers['content-disposition'];
      String filename = '';
      if (contentDisposition != null &&
          contentDisposition.contains('filename=')) {
        filename = contentDisposition.split('filename=')[1].replaceAll('"', '');
      } else {
        filename = document.name;
        // Add extension if not present
        if (!filename.contains('.') && document.fileType != null) {
          filename = '$filename.${document.fileType!.split('/').last}';
        }
      }

      // THIS IS WHERE THE NEW CODE GOES
      String? downloadsPath;
      if (Platform.isAndroid) {
        // Try primary path first
        downloadsPath = '/storage/emulated/0/Download';
        if (!Directory(downloadsPath).existsSync()) {
          // Try alternative path
          downloadsPath = '/storage/emulated/0/Downloads';
          if (!Directory(downloadsPath).existsSync()) {
            // Final fallback - get external storage and append Download
            final extDir = await getExternalStorageDirectory();
            if (extDir != null) {
              downloadsPath = '${extDir.path}/Download';
              // Create directory if it doesn't exist
              await Directory(downloadsPath).create(recursive: true);
            } else {
              throw Exception('Could not find Downloads directory');
            }
          }
        }
      } else {
        // For iOS, use documents directory
        final directory = await getApplicationDocumentsDirectory();
        downloadsPath = directory.path;
      }

      if (downloadsPath == null) {
        throw Exception('Could not access Downloads directory');
      }

      // Create the full file path
      final filePath = '$downloadsPath/$filename';
      final file = File(filePath);
      // END OF NEW CODE

      // Write the file
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document downloaded: $filename'),
                const SizedBox(height: 4),
                Text(
                  'Saved to Downloads folder',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  final result = await OpenFile.open(filePath);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening file: ${result.message}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not open file: $e'),
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

        // Try to open the file automatically
        try {
          await OpenFile.open(filePath);
        } catch (e) {
          print('Error auto-opening file: $e');
        }
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
  }

  Future<void> _deleteDocument(
      BuildContext context, DocumentProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Document',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${document.name}"?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          backgroundColor: theme.cardTheme.color,
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
              ),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipPath(
                  clipper: DocumentTileClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (isSelectionMode) {
                            provider.toggleSelection(document.id);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Preview or Checkbox
                              isSelectionMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) =>
                                          provider.toggleSelection(document.id),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      activeColor: theme.colorScheme.primary,
                                    )
                                  : DocumentPreview(
                                      fileType: document.fileType ?? '',
                                      filePath: document.filePath ?? '',
                                      token: provider.token,
                                      category: document.category,
                                    ),
                              const SizedBox(width: 16),
                              // Document Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      document.name,
                                      style: AppTextStyles.subtitle1.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 12,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          getRelativeDate(document.createdAt),
                                          style: AppTextStyles.caption.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (document.fileSize != null) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            formatFileSize(document.fileSize),
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Menu Button
                              if (!isSelectionMode)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  position: PopupMenuPosition.under,
                                  onSelected: (action) =>
                                      _handleMenuAction(context, action),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'info',
                                      child: _buildMenuItem(
                                        Icons.info_outline,
                                        'Info',
                                        theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: _buildMenuItem(
                                        Icons.edit_outlined,
                                        'Edit',
                                        theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'share',
                                      child: _buildMenuItem(
                                        Icons.share_outlined,
                                        'Share',
                                        theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'download',
                                      child: _buildMenuItem(
                                        Icons.download_outlined,
                                        'Download',
                                        theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: _buildMenuItem(
                                        Icons.delete_outline,
                                        'Delete',
                                        Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String getRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return formatDate(dateTime);
    }
  }
}
