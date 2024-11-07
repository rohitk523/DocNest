// lib/widgets/document_search.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';

class SearchDialog extends StatefulWidget {
  final List<Document> documents;

  const SearchDialog({super.key, required this.documents});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                // Update the search query in DocumentProvider
                context.read<DocumentProvider>().setSearchQuery(query);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<DocumentProvider>(
                builder: (context, documentProvider, child) {
                  final searchResults = documentProvider.filteredDocuments;

                  if (searchResults.isEmpty && _searchController.text.isEmpty) {
                    return const Center(
                      child: Text('Start typing to search documents'),
                    );
                  }

                  if (searchResults.isEmpty) {
                    return const Center(
                      child: Text('No results found'),
                    );
                  }

                  return ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final document = searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(document.name),
                        subtitle: Text(
                          document.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context, document);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    context
        .read<DocumentProvider>()
        .clearSearch(); // Clear search when dialog is closed
    super.dispose();
  }
}
