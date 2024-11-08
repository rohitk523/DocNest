// lib/widgets/document_category_tab.dart
import 'package:flutter/material.dart';
import '../models/document.dart';
import 'document_tile.dart';

class DocumentCategoryTab extends StatelessWidget {
  final List<Document> documents;
  final String category;
  final bool isLoading;
  final VoidCallback onRefresh;

  const DocumentCategoryTab({
    Key? key,
    required this.documents,
    required this.category,
    required this.isLoading,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryDocuments = documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: categoryDocuments.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: categoryDocuments.length,
              itemBuilder: (context, index) {
                return DocumentTile(document: categoryDocuments[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No $category documents yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
