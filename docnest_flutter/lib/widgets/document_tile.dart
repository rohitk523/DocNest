import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../services/documents/cache_service.dart';
import '../services/documents/deletion_service.dart';
import '../services/documents/editing_service.dart';
import '../services/documents/sharing_service.dart';
import '../theme/app_theme.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import '../providers/document_provider.dart';
import '../config/api_config.dart';
import '../widgets/custom_snackbar.dart';

class DocumentTileClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    const double wedgeWidth = 120.0;
    const double flatBottomWidth = 40.0;
    const double wedgeHeight = 13.0;
    const double cornerRadius = 20.0;

    final center = size.width / 2;

    path.moveTo(cornerRadius, 0);
    path.lineTo(center - wedgeWidth / 2, 0);
    path.lineTo(center - flatBottomWidth / 2, wedgeHeight);
    path.lineTo(center + flatBottomWidth / 2, wedgeHeight);
    path.lineTo(center + wedgeWidth / 2, 0);
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
        size.width, size.height, size.width - cornerRadius, size.height);
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);
    path.lineTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _DocumentTilePreview extends StatefulWidget {
  final Document document;

  const _DocumentTilePreview({
    required this.document,
  });

  @override
  State<_DocumentTilePreview> createState() => _DocumentTilePreviewState();
}

class _DocumentTilePreviewState extends State<_DocumentTilePreview> {
  final CacheService _cacheService = CacheService();
  late Future<Widget> _previewWidget;

  @override
  void initState() {
    super.initState();
    _previewWidget = _loadPreview();
  }

  Future<Widget> _loadPreview() async {
    try {
      if (widget.document.filePath == null) {
        return _buildCategoryIcon();
      }

      // Check if preview exists in cache
      final preview = await _cacheService.getPreview(widget.document.filePath!);
      if (preview != null) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(preview),
              fit: BoxFit.cover,
            ),
          ),
        );
      }

      return _buildCategoryIcon();
    } catch (e) {
      print('Error loading preview: $e');
      return _buildCategoryIcon();
    }
  }

  Widget _buildCategoryIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: getCategoryColor(widget.document.category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        getCategoryIcon(widget.document.category),
        color: getCategoryColor(widget.document.category),
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _previewWidget,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Preview error: ${snapshot.error}');
          return _buildCategoryIcon();
        }

        return snapshot.data ?? _buildCategoryIcon();
      },
    );
  }
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
    final tileHeight = 80.0;

    if (details.globalPosition.dy < tileHeight) {
      _scrollSpeed = (tileHeight - details.globalPosition.dy) / tileHeight * 10;
    } else if (details.globalPosition.dy > screenHeight - tileHeight) {
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
    await DocumentEditingService.editDocument(
      context: context,
      document: widget.document,
      provider: provider,
    );
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

      // First try to get from cache
      final cachedBytes = await CacheService().getFromCache(
        widget.document.filePath ?? '',
        widget.document.fileType ?? '',
      );

      if (cachedBytes != null) {
        // Use cached file
        await _saveAndShowSuccess(context, cachedBytes);
        return;
      }

      // If not in cache, download from server
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}${widget.document.id}/download'),
        headers: ApiConfig.authHeaders(provider.token),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download document');
      }

      await _saveAndShowSuccess(context, response.bodyBytes);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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

  Future<void> _saveAndShowSuccess(
      BuildContext context, List<int> bytes) async {
    String? downloadsPath;
    if (Platform.isAndroid) {
      downloadsPath = '/storage/emulated/0/Download';
      if (!Directory(downloadsPath).existsSync()) {
        downloadsPath = '/storage/emulated/0/Downloads';
        if (!Directory(downloadsPath).existsSync()) {
          final extDir = await getExternalStorageDirectory();
          downloadsPath = extDir?.path;
        }
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      downloadsPath = directory.path;
    }

    if (downloadsPath == null) {
      throw Exception('Could not access Downloads directory');
    }

    final fileName = widget.document.name;
    final filePath = '$downloadsPath/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    if (context.mounted) {
      Navigator.pop(context);
      CustomSnackBar.showSuccess(
        context: context,
        title: 'Document Downloaded',
        message: 'Document saved to Downloads folder',
      );
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

  Future<void> _openDocument(BuildContext context) async {
    final provider = Provider.of<DocumentProvider>(context, listen: false);
    await DocumentSharingService.openDocument(
      context,
      widget.document,
      provider.token,
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
                                    : _DocumentTilePreview(
                                        document: widget.document,
                                      ),
                                const SizedBox(width: 16),
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
