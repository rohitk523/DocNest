// lib/widgets/document_section.dart

import 'package:docnest_flutter/widgets/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import '../providers/document_provider.dart';
import '../services/documents/editing_service.dart';
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

            await DocumentEditingService.updateDocumentCategory(
              context: context,
              documentId: document.id,
              newCategory: widget.title,
              provider: provider,
            );
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
