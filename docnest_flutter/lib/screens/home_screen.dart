// lib/screens/home_screen.dart
import 'package:docnest_flutter/screens/category_documents_screen.dart';
import 'package:docnest_flutter/widgets/add_category_dialog.dart';
import 'package:docnest_flutter/widgets/fluid_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_snackbar.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isDragging = false;

  final List<String> _defaultCategories = [
    'government',
    'medical',
    'educational',
    'other'
  ];
  List<String> _userCategories = [];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          CustomSnackBar.showError(
            context: context,
            title: 'Upload Error',
            message: 'Error uploading document: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: _handleUpload,
          );
        }
      }
    }
  }

  Future<void> _handleAuthError() async {
    await _storage.delete(key: 'auth_token');
    if (mounted) {
      CustomSnackBar.showError(
        context: context,
        title: 'Session Expired',
        message: 'Session expired. Please log in again.',
      );

// After showing the snackbar, navigate to the login screen
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
              ? _buildCategoryList(documents)
              : _buildCategoryGrid(),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final provider = context.watch<DocumentProvider>();
    final theme = Theme.of(context);
    final categories = provider.allCategories;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: categories.length + 1, // +1 for "Add Category" card
      itemBuilder: (context, index) {
        // Add Category Card
        if (index == categories.length) {
          return Hero(
            tag: 'category_add_new',
            child: Material(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: InkWell(
                  onTap: _handleAddCategory,
                  child: Card(
                    elevation: 8,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.3),
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
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.primary.withOpacity(0.2),
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
                              Icons.add_circle_outline,
                              size: 100,
                              color: theme.colorScheme.primary.withOpacity(0.1),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon container
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add_circle_outline,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const Spacer(),
                                // Title and description
                                Text(
                                  'Add Category',
                                  style: AppTextStyles.subtitle1.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create a custom category',
                                  style: AppTextStyles.caption.copyWith(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7),
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
        }

        // Regular Category Cards
        final category = categories[index];
        final docs = provider.documents
            .where(
                (doc) => doc.category.toLowerCase() == category.toLowerCase())
            .toList();
        final isCustomCategory = provider.isCustomCategory(category);

        return Hero(
          tag: 'category_$category',
          child: Material(
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
                        getCategoryColor(category).withOpacity(0.1),
                        getCategoryColor(category).withOpacity(0.2),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                if (isCustomCategory)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () =>
                                        _handleDeleteCategory(category),
                                  ),
                              ],
                            ),
                            const Spacer(),
                            // Category name and document count
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        getCategoryDisplayName(category),
                                        style: AppTextStyles.subtitle1.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${docs.length} document${docs.length != 1 ? 's' : ''}',
                                        style: AppTextStyles.caption.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCustomCategory)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getCategoryBadgeColor(category),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Custom',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: getCategoryColor(category),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
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
        );
      },
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      double scrollSpeed = 0.0;
      const double scrollThreshold = 100.0;
      const double scrollAcceleration = 5.0;

      if (details.globalPosition.dy < scrollThreshold) {
        scrollSpeed =
            (scrollThreshold - details.globalPosition.dy) * scrollAcceleration;
      } else if (details.globalPosition.dy >
          MediaQuery.of(context).size.height - scrollThreshold) {
        scrollSpeed = (details.globalPosition.dy -
                (MediaQuery.of(context).size.height - scrollThreshold)) *
            scrollAcceleration;
      }

      if (scrollSpeed != 0) {
        _scrollController.animateTo(
          _scrollController.offset + scrollSpeed,
          duration: const Duration(milliseconds: 16),
          curve: Curves.linear,
        );
      }
    }
  }

  // Inside _HomeScreenState class in home_screen.dart, modify _buildCategoryList:

  Widget _buildCategoryList(List<Document> documents) {
    final theme = Theme.of(context);
    final provider = Provider.of<DocumentProvider>(context);

    return GestureDetector(
      onVerticalDragUpdate: _handleDragUpdate,
      child: RefreshIndicator(
        onRefresh: _loadDocuments,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surface,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount:
              provider.allCategories.length + 1, // +1 for "Add New Category"
          separatorBuilder: (context, index) {
            if (index >= provider.allCategories.length)
              return const SizedBox.shrink();

            final category = provider.allCategories[index];
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
            // Handle the "Add New Category" option
            if (index == provider.allCategories.length) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: _handleAddCategory,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add New Category',
                                  style: AppTextStyles.subtitle1.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Create a custom category for your documents',
                                  style: AppTextStyles.caption.copyWith(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final category = provider.allCategories[index];
            final isCustomCategory = provider.isCustomCategory(category);
            final categoryDocuments = _getDocumentsByCategory(category);

            return AnimatedSlide(
              duration: Duration(milliseconds: 300 + (index * 100)),
              offset: const Offset(0, 0),
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300 + (index * 100)),
                opacity: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryDocumentsScreen(
                            category: category,
                            documents: categoryDocuments,
                          ),
                        ),
                      );
                    },
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
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: getCategoryColor(category)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  getCategoryDisplayName(
                                                      category),
                                                  style: AppTextStyles.subtitle1
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme
                                                        .colorScheme.onSurface,
                                                  ),
                                                ),
                                                if (isCustomCategory) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          getCategoryBadgeColor(
                                                              category),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    child: Text(
                                                      'Custom',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: getCategoryColor(
                                                            category),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '${categoryDocuments.length} document${categoryDocuments.length != 1 ? 's' : ''}',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isCustomCategory)
                                        IconButton(
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          color: Colors.red,
                                          onPressed: () =>
                                              _handleDeleteCategory(category),
                                        ),
                                      const Icon(
                                        Icons.keyboard_arrow_right,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
              ),
            );
          },
        ),
      ),
    );
  }

  // Add these new methods to _HomeScreenState:
  void _handleAddCategory() async {
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AddCategoryDialog(
        defaultCategories: context.read<DocumentProvider>().defaultCategories,
      ),
    );

    if (newCategory != null && mounted) {
      try {
        final success = await context
            .read<DocumentProvider>()
            .addCustomCategory(newCategory);
        if (success && mounted) {
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Category Added',
            message:
                'Category "${getCategoryDisplayName(newCategory)}" added successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.showError(
            context: context,
            title: 'Category Error',
            message: 'Failed to add category: $e',
          );
        }
      }
    }
  }

  void _handleDeleteCategory(String category) async {
    final provider = context.read<DocumentProvider>();

    // Check if category has documents
    final documents = _getDocumentsByCategory(category);
    if (documents.isNotEmpty) {
      if (mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Delete Error',
          message:
              'Cannot delete category with documents. Move or delete the documents first.',
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text(
            'Are you sure you want to delete "${getCategoryDisplayName(category)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await provider.removeCustomCategory(category);
        if (success && mounted) {
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Category Deleted',
            message: 'Category deleted successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.showError(
            context: context,
            title: 'Delete Error',
            message: 'Failed to delete category: $e',
          );
        }
      }
    }
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

          CustomSnackBar.showSuccess(
            context: context,
            title: 'Upload Success',
            message: 'Document uploaded successfully',
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
          CustomSnackBar.showError(
            context: context,
            title: 'Loading Error',
            message: 'Error loading documents: ${e.toString()}',
            actionLabel: 'Retry',
            onAction: _loadDocuments,
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
