// lib/widgets/document_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';

class DocumentSection extends StatelessWidget {
  final String title;
  final List<Document> documents;

  const DocumentSection({
    super.key,
    required this.title,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Helvetica',
            ),
          ),
        ),
        Card(
          child: Consumer<DocumentProvider>(
            builder: (context, documentProvider, child) {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final bool isSelected =
                      documentProvider.isDocumentSelected(document.id);
                  final bool isSelectionMode = documentProvider.isSelectionMode;

                  return ListTile(
                    leading: isSelectionMode
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade300,
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                          )
                        : const Icon(Icons.description),
                    title: Text(
                      document.name,
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      document.createdAt.toString().split(' ')[0],
                      style: const TextStyle(fontFamily: 'Helvetica'),
                    ),
                    trailing: isSelectionMode
                        ? null
                        : const Icon(Icons.arrow_forward_ios),
                    tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                    onTap: () {
                      if (isSelectionMode) {
                        documentProvider.toggleDocumentSelection(document.id);
                      } else {
                        // Handle document tap
                      }
                    },
                    onLongPress: () {
                      if (!isSelectionMode) {
                        documentProvider.toggleSelectionMode();
                        documentProvider.toggleDocumentSelection(document.id);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
