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
      await provider.updateDocumentCategory(document.id, newCategory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to ${newCategory.toLowerCase()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move document: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
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
          onAccept: (document) {
            setState(() => _isDropTarget = false);
            provider.endDragging();
            _updateDocumentCategory(document, widget.title);
          },
          onLeave: (_) {
            setState(() => _isDropTarget = false);
            provider.endDragging();
          },
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                getCategoryColor(widget.title).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            getCategoryIcon(widget.title),
                            color: getCategoryColor(widget.title),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title[0].toUpperCase() +
                                    widget.title.substring(1),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${widget.documents.length} document${widget.documents.length != 1 ? 's' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelectionMode)
                          Chip(
                            label: Text(
                              '${provider.selectedDocuments.where((doc) => doc.category.toLowerCase() == widget.title.toLowerCase()).length} selected',
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isSelectionMode)
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.documents.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        provider.reorderDocuments(
                            widget.title, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final document = widget.documents[index];
                        return Draggable<Document>(
                          key: ValueKey(document.id),
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
                                color:
                                    theme.colorScheme.outline.withOpacity(0.5),
                              ),
                            ),
                          ),
                          onDragStarted: provider.startDragging,
                          onDragEnd: (_) => provider.endDragging(),
                          onDraggableCanceled: (_, __) =>
                              provider.endDragging(),
                          child: DocumentTile(document: document),
                        );
                      },
                    )
                  else
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
