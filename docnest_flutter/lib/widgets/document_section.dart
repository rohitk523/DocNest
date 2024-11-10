// lib/widgets/document_section.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../utils/formatters.dart';
import './document_tile.dart';

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

    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.only(top: 24), // Add top spacing between sections
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: getCategoryColor(title).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getCategoryIcon(title),
                    color: getCategoryColor(title),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Category title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title[0].toUpperCase() + title.substring(1),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${documents.length} document${documents.length != 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16), // Spacing between header and list
          // Documents list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: documents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final document = documents[index];
              return DocumentTile(document: document);
            },
          ),
          // Bottom border for visual separation
          Container(
            margin: const EdgeInsets.only(top: 24),
            height: 1,
            color: theme.dividerColor.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}
