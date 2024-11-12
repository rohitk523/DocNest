// lib/widgets/search_bar_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../screens/search_results_screen.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({Key? key}) : super(key: key);

  void _handleSearch(BuildContext context, String query) {
    if (query.trim().isEmpty) return;

    final provider = context.read<DocumentProvider>();
    final results = provider.searchDocuments(query.trim());
    provider.addToSearchHistory(query.trim());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          searchQuery: query.trim(),
          searchResults: results,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search documents',
        hintStyle: const TextStyle(fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Get the current text from the TextField
            final textField =
                context.findAncestorWidgetOfExactType<TextField>();
            if (textField != null && textField.controller?.text != null) {
              _handleSearch(context, textField.controller!.text);
            }
          },
        ),
      ),
      onSubmitted: (value) => _handleSearch(context, value),
      textInputAction: TextInputAction.search,
    );
  }
}
