// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../models/document.dart';
import '../widgets/document_tile.dart'; // Import DocumentTile
import '../utils/formatters.dart';

class SearchScreen extends StatefulWidget {
  final String searchQuery;
  final List<Document> documents;
  final Document? selectedDocument;

  const SearchScreen({
    Key? key,
    required this.searchQuery,
    required this.documents,
    this.selectedDocument,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search Results'),
            Text(
              'for "${widget.searchQuery}"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.selectedDocument != null)
            _SelectedDocumentSection(document: widget.selectedDocument!),
          Expanded(
            child: _DocumentList(
              documents: widget.documents,
              selectedDocumentId: widget.selectedDocument?.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDocumentSection extends StatelessWidget {
  final Document document;

  const _SelectedDocumentSection({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Document',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DocumentTile(document: document), // Using DocumentTile
          const Divider(),
          Text(
            'Other Results',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  final List<Document> documents;
  final String? selectedDocumentId;

  const _DocumentList({
    required this.documents,
    this.selectedDocumentId,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final document = documents[index];
        if (document.id == selectedDocumentId) {
          return const SizedBox.shrink();
        }
        return DocumentTile(document: document); // Using DocumentTile
      },
    );
  }
}

class SearchOverlay extends StatefulWidget {
  const SearchOverlay({Key? key}) : super(key: key);

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _navigateToResults(BuildContext context,
      {Document? selectedDocument}) async {
    if (_isNavigating || _searchQuery.trim().isEmpty) return;

    setState(() => _isNavigating = true);

    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      final results = provider.searchDocuments(_searchQuery.trim());

      await _controller.reverse();

      if (!mounted) return;

      Navigator.of(context).pop();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => SearchScreen(
            searchQuery: _searchQuery.trim(),
            documents: results,
            selectedDocument: selectedDocument,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.black54,
        child: FadeTransition(
          opacity: _animation,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            autofocus: true,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search documents...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            onFieldSubmitted: (_) =>
                                _navigateToResults(context),
                          ),
                          if (_searchQuery.isNotEmpty)
                            _LiveSearchResults(
                              query: _searchQuery,
                              onDocumentSelected: (doc) => _navigateToResults(
                                context,
                                selectedDocument: doc,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _LiveSearchResults extends StatelessWidget {
  final String query;
  final ValueChanged<Document> onDocumentSelected;

  const _LiveSearchResults({
    required this.query,
    required this.onDocumentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentProvider>(
      builder: (context, provider, _) {
        final results = provider.searchDocuments(query);

        if (results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No results found'),
          );
        }

        return SizedBox(
          height: 300,
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final document = results[index];
              return InkWell(
                onTap: () => onDocumentSelected(document),
                child: DocumentTile(document: document), // Using DocumentTile
              );
            },
          ),
        );
      },
    );
  }
}

void showDocumentSearch(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, _, __) => const SearchOverlay(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ),
  );
}
