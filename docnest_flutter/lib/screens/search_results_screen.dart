// lib/screens/search_results_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../widgets/quick_actions_bar.dart';
import '../widgets/document_tile.dart';
import '../models/document.dart';

class SearchResultsScreen extends StatelessWidget {
  final String searchQuery;
  final List<Document> searchResults;

  const SearchResultsScreen({
    Key? key,
    required this.searchQuery,
    required this.searchResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search Results'),
            Text(
              'for "$searchQuery"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${searchResults.length} ${searchResults.length == 1 ? 'result' : 'results'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const QuickActionsBar(),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found for "$searchQuery"',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      return DocumentTile(
                        document: searchResults[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
