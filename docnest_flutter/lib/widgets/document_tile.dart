import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../services/documents/cache_service.dart';
import '../services/documents/document_deletion_service.dart';
import '../services/documents/document_sharing_service.dart';
import '../theme/app_theme.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import '../providers/document_provider.dart';
import '../widgets/edit_document_dialog.dart';
import '../services/document_service.dart';
import '../config/api_config.dart';
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

    // Calculate center position
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

class DocumentTile extends StatefulWidget {
  final Document document;
  final bool isDragging;

  const DocumentTile({
    Key? key,
    required this.document,
    this.isDragging = false,
  }) : super(key: key);

  @override
  _DocumentTileState createState() => _DocumentTileState();
}

class _DocumentTileState extends State<DocumentTile> {
  ScrollController? _scrollController;
  double _scrollSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController?.dispose();
    super.dispose();
  }

  void _startScrolling(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final tileHeight = 80.0; // Adjust this value based on your tile height

    if (details.globalPosition.dy < tileHeight) {
      // Scroll up
      _scrollSpeed = (tileHeight - details.globalPosition.dy) / tileHeight * 10;
    } else if (details.globalPosition.dy > screenHeight - tileHeight) {
      // Scroll down
      _scrollSpeed = (details.globalPosition.dy - (screenHeight - tileHeight)) /
          tileHeight *
          10;
    } else {
      _scrollSpeed = 0.0;
    }
  }

  void _stopScrolling() {
    _scrollSpeed = 0.0;
  }

  void _handleScroll() {
    if (_scrollSpeed != 0.0) {
      _scrollController?.animateTo(
        _scrollController!.offset + _scrollSpeed,
        duration: const Duration(milliseconds: 16),
        curve: Curves.linear,
      );
      Future.delayed(const Duration(milliseconds: 16), _handleScroll);
    }
  }

  Future<void> _handleEdit(
      BuildContext context, DocumentProvider provider) async {
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
        builder: (context) => EditDocumentDialog(document: widget.document),
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
          documentId: widget.document.id,
          name: result['name'],
          description: result['description'],
          category: result['category'],
        );

        provider.updateDocument(updatedDoc);

        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading dialog
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Upload Successful',
            message: 'Document uploaded successfully',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog if showing
        CustomSnackBar.showError(
          context: context,
          title: 'Error Updating Document',
          message: 'Error updating document: $e',
          actionLabel: 'Retry',
          onAction: () => _handleEdit(context, provider),
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
        await _handleShare(context);
        break;
      case 'download':
        await _downloadDocument(context);
        break;
      case 'print':
        await _printDocument(context);
        break;
      case 'delete':
        await _handleDelete(context, provider);
        break;
      case 'edit':
        await _handleEdit(context, provider);
        break;
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    await DocumentSharingService.shareDocument(
      context,
      widget.document,
      provider.token,
    );
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
              _metadataRow('Name', widget.document.name),
              _metadataRow('Category', widget.document.category),
              _metadataRow('Description', widget.document.description ?? ''),
              _metadataRow(
                  'File Size', formatFileSize(widget.document.fileSize)),
              _metadataRow('File Type', widget.document.fileType ?? 'N/A'),
              _metadataRow(
                  'Created', formatDateDetailed(widget.document.createdAt)),
              _metadataRow(
                  'Modified', formatDateDetailed(widget.document.modifiedAt)),
              _metadataRow('Version', widget.document.version.toString()),
              _metadataRow('Shared', widget.document.isShared ? 'Yes' : 'No'),
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
        Uri.parse('${ApiConfig.documentsUrl}${widget.document.id}/download'),
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
        filename = widget.document.name;
        // Add extension if not present
        if (!filename.contains('.') && widget.document.fileType != null) {
          filename = '$filename.${widget.document.fileType!.split('/').last}';
        }
      }

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

      // Write the file
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        // Dismiss loading dialog
        Navigator.pop(context);

        // Show success message
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Document Downloaded',
          message: 'Document downloaded: $filename\nSaved to Downloads folder',
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Dismiss loading dialog if showing
        Navigator.pop(context);

        // Show error message
        CustomSnackBar.showError(
          context: context,
          title: 'Error Downloading Document',
          message: 'Error: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => _downloadDocument(context),
        );
      }
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    final cacheService = CacheService();
    final fileName = widget.document.name;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening document...'),
            ],
          ),
        ),
      );

      // Try to get cached file
      File? cachedFile = await cacheService.getCachedDocumentByName(fileName);

      if (cachedFile == null || !await cachedFile.exists()) {
        // If not cached, download and cache
        final response = await http.get(
          Uri.parse('${ApiConfig.documentsUrl}${widget.document.id}/download'),
          headers: ApiConfig.authHeaders(provider.token),
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to fetch document file');
        }

        await cacheService.cacheDocumentWithName(fileName, response.bodyBytes);
        cachedFile = await cacheService.getCachedDocumentByName(fileName);
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
      }

      if (cachedFile != null) {
        await OpenFilex.open(cachedFile.path, type: widget.document.fileType);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar(context, 'Error opening document: ${e.toString()}');
      }
    }
  }

  Future<void> _handleDelete(
      BuildContext context, DocumentProvider provider) async {
    await DocumentDeletionService.deleteSingleDocument(
      context: context,
      document: widget.document,
      provider: provider,
    );
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

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isSelected(widget.document.id);
        final isSelectionMode = provider.isSelectionMode;
        final theme = Theme.of(context);

        return Listener(
          onPointerMove: (event) {
            if (widget.isDragging) {
              _startScrolling(event as DragUpdateDetails);
              _handleScroll();
            }
          },
          onPointerUp: (_) => _stopScrolling(),
          onPointerCancel: (_) => _stopScrolling(),
          child: Padding(
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
                              provider.toggleSelection(widget.document.id);
                            } else {
                              _openDocument(context);
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
                                            provider.toggleSelection(
                                                widget.document.id),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        activeColor: theme.colorScheme.primary,
                                      )
                                    : DocumentPreview(
                                        fileType:
                                            widget.document.fileType ?? '',
                                        filePath:
                                            widget.document.filePath ?? '',
                                        token: provider.token,
                                        category: widget.document.category,
                                        document: widget.document,
                                      ),
                                const SizedBox(width: 16),
                                // Document Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.document.name,
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
                                            getRelativeDate(
                                                widget.document.createdAt),
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (widget.document.fileSize !=
                                              null) ...[
                                            const SizedBox(width: 12),
                                            Text(
                                              formatFileSize(
                                                  widget.document.fileSize),
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
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
