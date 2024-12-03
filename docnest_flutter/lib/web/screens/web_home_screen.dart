// lib/web/screens/web_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/document_provider.dart';
import '../../services/documents/cache_service.dart';
import '../../services/documents/download_service.dart';
import '../../services/documents/uploading_service.dart';
import '../../widgets/document_section.dart';
import '../../widgets/custom_snackbar.dart';
import '../../utils/formatters.dart';
import '../../models/document.dart';
import '../../services/document_service.dart';
import '../../mobile/screens/login_screen.dart';
import '../../widgets/add_category_dialog.dart';
import '../../theme/app_theme.dart';
import '../../mobile/screens/profile_tab.dart';
import '../../widgets/document_tile.dart';
import '../../widgets/settings_tab.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebHomeScreen extends StatefulWidget {
  final String token;

  const WebHomeScreen({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> {
  bool _isLoading = true;
  bool _isSidebarCollapsed = false;
  String _selectedCategory = 'all';
  String _selectedTab = 'home';
  late DocumentService _documentService;
  final CacheService _cacheService = CacheService();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(token: widget.token);
    Future.microtask(() => _initializeData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      print('Starting initialization...');
      final provider = context.read<DocumentProvider>();
      if (provider.token != widget.token) {
        print('Updating token: ${widget.token.substring(0, 10)}...');
        provider.updateToken(widget.token);
      }
      print('Initializing provider...');
      await provider.initialize();
      print(
          'Provider initialized, document count: ${provider.documents.length}');
    } catch (e, stackTrace) {
      print('Error in initialization: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load documents: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          print('Loading state set to false');
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await const FlutterSecureStorage().delete(key: 'auth_token');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _handleAddCategory() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AddCategoryDialog(
        defaultCategories: context.read<DocumentProvider>().defaultCategories,
      ),
    );

    if (result != null && mounted) {
      try {
        final success =
            await context.read<DocumentProvider>().addCustomCategory(result);
        if (success && mounted) {
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Category Added',
            message:
                'Category "${getCategoryDisplayName(result)}" added successfully',
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

  Future<void> _handleDeleteCategory(String category) async {
    final provider = context.read<DocumentProvider>();
    final documents = provider.getDocumentsByCategory(category);

    if (documents.isNotEmpty) {
      CustomSnackBar.showError(
        context: context,
        title: 'Delete Error',
        message: 'Cannot delete category with documents',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${getCategoryDisplayName(category)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await provider.removeCustomCategory(category);
        if (mounted) {
          CustomSnackBar.showSuccess(
            context: context,
            title: 'Success',
            message: 'Category deleted successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to delete category: $e',
          );
        }
      }
    }
  }

  Widget _buildSideNavigation(DocumentProvider provider) {
    final theme = Theme.of(context);
    return Container(
      width: _isSidebarCollapsed ? 80 : 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(theme),
          _buildNavigationItems(theme),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: _buildCategoryList(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarCollapsed ? 16 : 24,
        vertical: 24,
      ),
      child: Row(
        children: [
          Image.asset('assets/images/DocNest.png', height: 32),
          if (!_isSidebarCollapsed) ...[
            const SizedBox(width: 12),
            Text(
              'DocNest',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
          ],
          IconButton(
            icon: Icon(
              _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
            ),
            onPressed: () {
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(ThemeData theme) {
    return Column(
      children: [
        _buildNavItem('home', 'Home', Icons.home_outlined, theme),
        _buildNavItem('profile', 'Profile', Icons.person_outline, theme),
        _buildNavItem('settings', 'Settings', Icons.settings_outlined, theme),
      ],
    );
  }

  Widget _buildNavItem(
      String id, String label, IconData icon, ThemeData theme) {
    final isSelected = _selectedTab == id;
    return ListTile(
      selected: isSelected,
      leading: Icon(icon),
      title: _isSidebarCollapsed ? null : Text(label),
      onTap: () => setState(() => _selectedTab = id),
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      selectedColor: theme.colorScheme.primary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: _isSidebarCollapsed ? 16 : 24,
        vertical: 4,
      ),
    );
  }

  Widget _buildCategoryList(DocumentProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isSidebarCollapsed)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        _buildCategoryItem(
            'all', 'All Documents', Icons.folder, provider.documents),
        ...provider.defaultCategories.map((category) {
          final docs = provider.getDocumentsByCategory(category);
          return _buildCategoryItem(
            category,
            getCategoryDisplayName(category),
            getCategoryIcon(category),
            docs,
          );
        }),
        if (provider.customCategories.isNotEmpty && !_isSidebarCollapsed) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Custom Categories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...provider.customCategories.map((category) {
            final docs = provider.getDocumentsByCategory(category);
            return _buildCategoryItem(
              category,
              getCategoryDisplayName(category),
              getCategoryIcon(category),
              docs,
              isCustom: true,
            );
          }),
        ],
        const SizedBox(height: 16),
        if (!_isSidebarCollapsed) _buildAddCategoryButton(),
      ],
    );
  }

  Widget _buildCategoryItem(
      String id, String label, IconData icon, List<Document> documents,
      {bool isCustom = false}) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == id.toLowerCase();
    final color = getCategoryColor(id);

    return ListTile(
      selected: isSelected,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${documents.length}'),
          if (isCustom) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _handleDeleteCategory(id),
            ),
          ],
        ],
      ),
      onTap: () => setState(() => _selectedCategory = id.toLowerCase()),
      selectedTileColor: color.withOpacity(0.1),
      selectedColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildAddCategoryButton() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _handleAddCategory,
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(DocumentProvider provider) {
    if (_selectedTab == 'profile') return const ProfileTab();
    if (_selectedTab == 'settings') return SettingsTab();

    final theme = Theme.of(context);
    final documents = _selectedCategory == 'all'
        ? provider.documents
        : provider.getDocumentsByCategory(_selectedCategory);

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          _buildTopBar(theme),
          Expanded(
            child: Container(
              color: theme.scaffoldBackgroundColor,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(documents.length),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (documents.isEmpty)
                        _buildEmptyState(theme)
                      else
                        _buildDocumentList(documents, theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(List<Document> documents, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: documents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final document = documents[index];
        return DocumentTile(document: document);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 100,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'No documents in this category',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => DocumentUploadingService.showUploadDialog(
                context,
                preSelectedCategory:
                    _selectedCategory == 'all' ? null : _selectedCategory,
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => DocumentUploadingService.showUploadDialog(context),
            tooltip: 'Upload Document',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int documentCount) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getCategoryDisplayName(_selectedCategory),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$documentCount ${documentCount == 1 ? 'document' : 'documents'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => DocumentUploadingService.showUploadDialog(
                context,
                preSelectedCategory:
                    _selectedCategory == 'all' ? null : _selectedCategory,
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSideNavigation(provider),
              Expanded(
                child: _buildMainContent(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
