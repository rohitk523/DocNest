import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../services/document_service.dart';
import 'package:provider/provider.dart';
import './document_tile.dart';

class DraggableDocumentList extends StatefulWidget {
  final String category;
  final List<Document> documents;
  final String token;

  const DraggableDocumentList({
    Key? key,
    required this.category,
    required this.documents,
    required this.token,
  }) : super(key: key);

  @override
  State<DraggableDocumentList> createState() => _DraggableDocumentListState();
}

class _DraggableDocumentListState extends State<DraggableDocumentList> {
  bool _isDropTarget = false;

  Future<void> _updateDocumentCategory(
      Document document, String newCategory) async {
    final documentService = DocumentService(token: widget.token);
    try {
      final updatedDoc = await documentService.updateDocument(
        documentId: document.id,
        category: newCategory,
      );

      if (mounted) {
        context.read<DocumentProvider>().updateDocument(updatedDoc);
        CustomSnackBar.showSuccess(
          context: context,
          title: 'Document Moved',
          message: 'Successfully moved to ${newCategory.toLowerCase()}',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Move Failed',
          message: 'Failed to move document: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<Document>(
      onWillAccept: (document) {
        // Only accept if document is from a different category
        setState(() => _isDropTarget = true);
        return document?.category != widget.category;
      },
      onAccept: (document) {
        setState(() => _isDropTarget = false);
        _updateDocumentCategory(document, widget.category);
      },
      onLeave: (_) => setState(() => _isDropTarget = false),
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: _isDropTarget
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                    // Use dots pattern instead of dashed
                    style: BorderStyle.solid,
                  )
                : null,
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.documents.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final provider = context.read<DocumentProvider>();
              provider.reorderDocuments(
                widget.category,
                oldIndex,
                newIndex,
              );
            },
            itemBuilder: (context, index) {
              final document = widget.documents[index];
              return LongPressDraggable<Document>(
                key: ValueKey(document.id),
                data: document,
                feedback: Material(
                  elevation: 4,
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
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                  ),
                ),
                child: DocumentTile(document: document),
              );
            },
          ),
        );
      },
    );
  }
}
