import 'package:flutter/material.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';

class DocumentTile extends StatelessWidget {
  final Document document;
  final bool isDragging;

  const DocumentTile({
    Key? key,
    required this.document,
    this.isDragging = false,
  }) : super(key: key);

  void _handleMenuAction(BuildContext context, String action) {
    // Implement menu actions
    switch (action) {
      case 'info':
        _showInfo(context);
        break;
      case 'edit':
        _handleEdit(context);
        break;
      case 'download':
        _handleDownload(context);
        break;
      case 'delete':
        _handleDelete(context);
        break;
    }
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Name', document.name),
            _infoRow('Category', document.category),
            _infoRow('Created', formatDate(document.createdAt)),
            _infoRow('Modified', formatDate(document.modifiedAt)),
            _infoRow('File Type', document.fileType ?? 'N/A'),
            _infoRow('Size', formatFileSize(document.fileSize)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // Implement other handlers
  void _handleEdit(BuildContext context) {
    // Add edit implementation
  }

  void _handleDownload(BuildContext context) {
    // Add download implementation
  }

  void _handleDelete(BuildContext context) {
    // Add delete implementation
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isSelected(document.id);
        final isSelectionMode = provider.isSelectionMode;
        final theme = Theme.of(context);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: getCategoryColor(document.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSelectionMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => provider.toggleSelection(document.id),
                      activeColor: theme.colorScheme.primary,
                    )
                  : Icon(
                      getCategoryIcon(document.category),
                      color: getCategoryColor(document.category),
                    ),
            ),
            title: Text(
              document.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (document.description.isNotEmpty) ...[
                  Text(document.description),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(document.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    if (document.fileType != null) ...[
                      Icon(Icons.description,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        document.fileType!.split('/').last.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon:
                        Icon(Icons.more_vert, color: theme.colorScheme.primary),
                    onSelected: (action) => _handleMenuAction(context, action),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'info',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline),
                            SizedBox(width: 8),
                            Text('Info'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Download'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(document.id);
              }
            },
          ),
        );
      },
    );
  }
}
