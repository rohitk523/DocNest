import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import '../providers/document_provider.dart';
import './document_tile.dart';

class DocumentSection extends StatefulWidget {
  final String title;
  final List<Document> documents;

  const DocumentSection({
    super.key,
    required this.title,
    required this.documents,
  });

  @override
  State<DocumentSection> createState() => _DocumentSectionState();
}

class _DocumentSectionState extends State<DocumentSection> {
  bool _isDropTarget = false;

  Future<void> _updateDocumentCategory(
      Document document, String newCategory) async {
    final provider = context.read<DocumentProvider>();

    try {
      // Show loading dialog
      if (context.mounted) {
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
                    'Moving ${document.name} to ${newCategory.toLowerCase()}...'),
              ],
            ),
          ),
        );
      }

      // Update document category
      await provider.updateDocumentCategory(document.id, newCategory);

      if (mounted) {
        // Dismiss loading dialog
        Navigator.of(context).pop();

        // Show success message
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Document Moved',
          message: 'Successfully moved to ${newCategory.toLowerCase()}',
        );
      }
    } catch (e) {
      if (mounted) {
        // Dismiss loading dialog
        Navigator.of(context).pop();

        // Show error message
        CustomSnackBar.showError(
          context: context,
          title: 'Move Failed',
          message: 'Failed to move document: ${e.toString()}',
          actionLabel: 'Retry',
          onAction: () => _updateDocumentCategory(document, newCategory),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final isSelectionMode = provider.isSelectionMode;

        return DragTarget<Document>(
          onWillAccept: (document) {
            if (document?.category.toLowerCase() ==
                widget.title.toLowerCase()) {
              return false;
            }
            setState(() => _isDropTarget = true);
            return true;
          },
          onAccept: (document) async {
            setState(() => _isDropTarget = false);
            provider.endDragging();
            await _updateDocumentCategory(document, widget.title);
          },
          onLeave: (_) {
            setState(() => _isDropTarget = false);
            provider.endDragging();
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: _isDropTarget
                    ? Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        if (isSelectionMode)
                          Chip(
                            label: Text(
                              '${provider.selectedDocuments.where((doc) => doc.category.toLowerCase() == widget.title.toLowerCase()).length} selected',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isSelectionMode) ...[
                    for (var document in widget.documents)
                      LongPressDraggable<Document>(
                        data: document,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: DocumentTile(
                              document: document,
                              isDragging: true,
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          height: 100,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                        ),
                        onDragStarted: provider.startDragging,
                        onDragEnd: (_) => provider.endDragging(),
                        onDraggableCanceled: (_, __) => provider.endDragging(),
                        child: DocumentTile(document: document),
                      ),
                  ] else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.documents.length,
                      itemBuilder: (context, index) {
                        final document = widget.documents[index];
                        return DocumentTile(document: document);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
