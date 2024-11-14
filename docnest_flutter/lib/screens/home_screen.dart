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
import '../theme/app_theme.dart';

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
    final theme = Theme.of(context);

    return GridView.builder(
      padding: const EdgeInsets.all(12), // Reduced from 16
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8, // Reduced from 16
        crossAxisSpacing: 8, // Reduced from 16
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final docs = provider.documents
            .where((doc) => doc.category.toLowerCase() == category)
            .toList();

        return Hero(
          tag: 'category_$category',
          child: Material(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: InkWell(
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
                  elevation: 8,
                  shadowColor: getCategoryColor(category).withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          getCategoryGradient(category)[0].withOpacity(0.1),
                          getCategoryGradient(category)[1].withOpacity(0.2),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Background pattern
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            getCategoryIcon(category),
                            size: 100,
                            color: getCategoryColor(category).withOpacity(0.1),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon and count row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: getCategoryColor(category)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: getCategoryColor(category)
                                            .withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      getCategoryIcon(category),
                                      color: getCategoryColor(category),
                                      size: 24,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getCategoryBadgeColor(category),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      docs.length.toString(),
                                      style: AppTextStyles.caption.copyWith(
                                        color: getCategoryColor(category),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Category name
                              Text(
                                getCategoryDisplayName(category),
                                style: AppTextStyles.subtitle1.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Document count
                              Text(
                                '${docs.length} document${docs.length != 1 ? 's' : ''}',
                                style: AppTextStyles.caption.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Progress indicator
                              LinearProgressIndicator(
                                value: docs.length /
                                    (provider.documents.length > 0
                                        ? provider.documents.length
                                        : 1),
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  getCategoryColor(category),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(List<Document> documents) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: _categories.length,
        separatorBuilder: (context, index) {
          final category = _categories[index];
          final categoryDocuments = _getDocumentsByCategory(category);

          if (categoryDocuments.isEmpty) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Divider(
                  height: 48,
                  thickness: 1,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: theme.scaffoldBackgroundColor,
                  child: Text(
                    '${categoryDocuments.length} items',
                    style: AppTextStyles.caption.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        itemBuilder: (context, index) {
          final category = _categories[index];
          final categoryDocuments = _getDocumentsByCategory(category);

          if (categoryDocuments.isEmpty) {
            return const SizedBox.shrink();
          }

          return AnimatedSlide(
            duration: Duration(milliseconds: 300 + (index * 100)),
            offset: const Offset(0, 0),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 300 + (index * 100)),
              opacity: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: getCategoryColor(category).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Header
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              getCategoryColor(category).withOpacity(0.1),
                              getCategoryColor(category).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    getCategoryColor(category).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                getCategoryIcon(category),
                                color: getCategoryColor(category),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getCategoryDisplayName(category),
                                    style: AppTextStyles.subtitle1.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    '${categoryDocuments.length} document${categoryDocuments.length != 1 ? 's' : ''}',
                                    style: AppTextStyles.caption.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_right,
                              color: getCategoryColor(category),
                            ),
                          ],
                        ),
                      ),
                      // Documents List
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: DocumentSection(
                          title: category,
                          documents: categoryDocuments,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
