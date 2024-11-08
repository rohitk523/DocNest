// lib/widgets/document_tile.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';

class DocumentTile extends StatelessWidget {
  final Document document;

  const DocumentTile({
    Key? key,
    required this.document,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelected = provider.isSelected(document.id);
        final isSelectionMode = provider.isSelectionMode;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
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
                    )
                  : Icon(
                      getCategoryIcon(document.category),
                      color: getCategoryColor(document.category),
                    ),
            ),
            title: Text(
              document.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(document.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.straighten, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      formatFileSize(document.fileSize),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            selected: isSelected,
            selectedTileColor: Colors.blue.withOpacity(0.1),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(document.id);
              } else {
                // Handle document tap
              }
            },
            onLongPress: () {
              if (!isSelectionMode) {
                provider.toggleSelection(document.id);
              }
            },
          ),
        );
      },
    );
  }
}
