// lib/widgets/document_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../models/document.dart';
import '../utils/formatters.dart';

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
    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

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
            ),
          ),
        ),
        Card(
          child: Consumer<DocumentProvider>(
            builder: (context, provider, _) {
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: documents.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final document = documents[index];
                  final bool isSelected = provider.isSelected(document.id);
                  final bool isSelectionMode = provider.isSelectionMode;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: getCategoryColor(document.category)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        getCategoryIcon(document.category),
                        color: getCategoryColor(document.category),
                      ),
                    ),
                    title: Text(
                      document.name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(document.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (_) =>
                                provider.toggleSelection(document.id),
                          )
                        : const Icon(Icons.arrow_forward_ios),
                    tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
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
