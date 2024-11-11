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
            contentPadding: const EdgeInsets.all(8),
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
            subtitle: Text(document.description),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
            onTap: () {
              if (isSelectionMode) {
                provider.toggleSelection(document.id);
              }
            },
            onLongPress: () {
              if (!provider.isDragging) {
                provider.toggleSelection(document.id);
              }
            },
          ),
        );
      },
    );
  }
}
