// lib/screens/category_documents_screen.dart
import 'package:docnest_flutter/screens/login_screen.dart';
import 'package:docnest_flutter/widgets/quick_actions/category_quick_actions_bar.dart';
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/documents/uploading_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/document_tile.dart';
import '../widgets/quick_actions_bar.dart';
import '../providers/document_provider.dart';
import 'package:provider/provider.dart';

class CategoryDocumentsScreen extends StatefulWidget {
  final String category;
  final List<Document> documents;

  const CategoryDocumentsScreen({
    Key? key,
    required this.category,
    required this.documents,
  }) : super(key: key);

  @override
  State<CategoryDocumentsScreen> createState() =>
      _CategoryDocumentsScreenState();
}

class _CategoryDocumentsScreenState extends State<CategoryDocumentsScreen> {
  bool _isLoading = false;

  Future<void> _refreshDocuments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<DocumentProvider>();
      if (provider.token.isEmpty) {
        throw Exception('Authentication required');
      }
      await provider.refreshDocuments();
    } catch (e) {
      if (mounted) {
        final isAuthError = e.toString().contains('Authentication required') ||
            e.toString().contains('token');

        if (isAuthError) {
          CustomSnackBar.showError(
            context: context,
            title: 'Authentication Required',
            message: 'Please log in again to continue',
            actionLabel: 'Login',
            onAction: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
                (route) => false,
              );
            },
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Document> _getCategoryDocuments(BuildContext context) {
    return context
        .watch<DocumentProvider>()
        .documents
        .where((doc) =>
            doc.category.toLowerCase() == widget.category.toLowerCase())
        .toList();
  }

  Future<void> _handleUpload(BuildContext context) async {
    await DocumentUploadingService.showUploadDialog(context,
        preSelectedCategory: widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryDocuments = _getCategoryDocuments(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.category[0].toUpperCase()}${widget.category.substring(1)} Documents',
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshDocuments,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          CategoryQuickActionsBar(category: widget.category),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshDocuments,
              child: categoryDocuments.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No documents in this category',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _handleUpload(context),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Document'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: categoryDocuments.length,
                      itemBuilder: (context, index) {
                        return DocumentTile(document: categoryDocuments[index]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleUpload(context),
        child: const Icon(Icons.add),
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
