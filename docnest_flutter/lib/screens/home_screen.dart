// lib/screens/home_screen.dart
import 'package:docnest_flutter/screens/category_documents_screen.dart';
import 'package:docnest_flutter/widgets/fluid_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/profile_tab.dart';
import '../widgets/settings_tab.dart';
import '../widgets/upload_dialog.dart';
import '../widgets/document_section.dart';
import '../widgets/quick_actions_bar.dart';
import '../services/document_service.dart';
import '../models/document.dart';
import '../providers/document_provider.dart';
import '../screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/formatters.dart';

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({Key? key, required this.token}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isGridView = false;
  int _currentIndex = 1;
  bool _isLoading = true;
  bool _isError = false;
  String _errorMessage = '';
  late DocumentService _documentService;
  final _storage = const FlutterSecureStorage();

  final List<String> _categories = [
    'government',
    'medical',
    'educational',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    _documentService = DocumentService(token: widget.token);

    // Ensure token is set in provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<DocumentProvider>();
        if (provider.token != widget.token) {
          provider.updateToken(widget.token);
        }
        _loadDocuments();
      }
    });
  }

  Future<void> _loadDocuments() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
        _errorMessage = '';
      });

      final docs = await _documentService.getDocuments();

      if (mounted) {
        context.read<DocumentProvider>().setDocuments(docs);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = e.toString();
        });

        if (e.toString().contains('Could not validate credentials')) {
          _handleAuthError();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading documents: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _loadDocuments,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleAuthError() async {
    await _storage.delete(key: 'auth_token');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  List<Document> _getDocumentsByCategory(String category) {
    final provider = context.read<DocumentProvider>();
    return provider.documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to load documents',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadDocuments,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading documents...'),
          ],
        ),
      );
    }

    if (_isError) {
      return _buildErrorView();
    }

    final documents = context.watch<DocumentProvider>().documents;
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No documents yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _handleUpload(),
              icon: const Icon(Icons.add),
              label: const Text('Add your first document'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const QuickActionsBar(),
        const SizedBox(height: 16),
        Expanded(
          child: _isGridView
              ? _buildCategoryGrid()
              : _buildCategoryList(documents),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final provider = context.watch<DocumentProvider>();
    final categories = ['government', 'medical', 'educational', 'other'];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(20),
      mainAxisSpacing: 10,
      crossAxisSpacing: 5,
      children: categories.map((category) {
        final docs = provider.documents
            .where((doc) => doc.category.toLowerCase() == category)
            .toList();

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDocumentsScreen(
                  category: category,
                  documents: docs,
                ),
              ),
            );
          },
          child: Card(
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getCategoryColor(category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      getCategoryIcon(category),
                      color: getCategoryColor(category),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category[0].toUpperCase() + category.substring(1),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${docs.length} document${docs.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryList(List<Document> documents) {
    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.separated(
        // Changed from ListView.builder to ListView.separated
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _categories.length,
        // Add separator builder
        separatorBuilder: (context, index) {
          final category = _categories[index];
          final categoryDocuments = _getDocumentsByCategory(category);
          // Only show divider if the current category has documents
          if (categoryDocuments.isEmpty) {
            return const SizedBox.shrink();
          }
          return const Divider(
            height: 40, // Total height of the divider
            thickness: 0.5, // Thickness of the divider line
            indent: 16, // Starting space from left
            endIndent: 16, // Ending space from right
            color: Colors.grey, // Color of the divider
          );
        },
        itemBuilder: (context, index) {
          final category = _categories[index];
          final categoryDocuments = _getDocumentsByCategory(category);

          if (categoryDocuments.isEmpty) {
            return Container();
          }

          return DocumentSection(
            title: category,
            documents: categoryDocuments,
          );
        },
      ),
    );
  }

  Future<void> _handleUpload() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => const UploadDocumentDialog(),
      );

      if (result != null && mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading document...'),
              ],
            ),
          ),
        );

        final uploadedDoc = await _documentService.uploadDocument(
          name: result['name'],
          description: result['description'],
          category: result['category'],
          file: result['file'],
        );

        if (mounted) {
          // Dismiss loading dialog
          Navigator.pop(context);

          context.read<DocumentProvider>().addDocument(uploadedDoc);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // Dismiss loading dialog if showing
        Navigator.popUntil(context, (route) => route.isFirst);

        if (e.toString().contains('Could not validate credentials')) {
          _handleAuthError();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading document: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _handleUpload,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DocNest',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list : Icons.grid_view,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ProfileTab(),
          _buildHomeContent(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: FluidNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
      ),
      // floatingActionButton: _currentIndex == 1
      //     ? FloatingActionButton(
      //         child: Icon(Icons.add),
      //         onPressed: _handleUpload,
      //       )
      //     : null,
    );
  }
}
