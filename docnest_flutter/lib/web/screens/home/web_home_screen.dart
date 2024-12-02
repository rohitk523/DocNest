// lib/screens/web_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/document_provider.dart';
import '../../../widgets/document_section.dart';
import '../../../widgets/custom_snackbar.dart';
import '../../../utils/formatters.dart';
import '../../../models/document.dart';
import '../../../services/document_service.dart';
import '../../../services/documents/uploading_service.dart';
import '../../../mobile/screens/login_screen.dart';
import '../../../widgets/add_category_dialog.dart';
import '../../../widgets/quick_actions/home_quick_actions_bar.dart';
import '../../../mobile/screens/profile_tab.dart';
import '../../../widgets/settings_tab.dart';
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
  String _selectedCategory = 'all';
  String _selectedTab = 'home';
  late DocumentService _documentService;

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(token: widget.token);
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final provider = context.read<DocumentProvider>();
      await provider.initialize();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load documents: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await const FlutterSecureStorage().delete(key: 'auth_token');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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

  Widget _buildSideNav(BuildContext context, DocumentProvider provider) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          _buildNavItem('home', 'Home', Icons.home_outlined),
          _buildNavItem('profile', 'Profile', Icons.person_outline),
          _buildNavItem('settings', 'Settings', Icons.settings_outlined),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCategorySection('All Documents', provider.documents),
                ...provider.defaultCategories.map((category) {
                  final docs = provider.getDocumentsByCategory(category);
                  return _buildCategorySection(category, docs);
                }),
                if (provider.customCategories.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Custom Categories'),
                  ),
                  ...provider.customCategories.map((category) {
                    final docs = provider.getDocumentsByCategory(category);
                    return _buildCategorySection(category, docs,
                        isCustom: true);
                  }),
                ],
                TextButton.icon(
                  onPressed: _handleAddCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Category'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String id, String label, IconData icon) {
    final isSelected = _selectedTab == id;
    final theme = Theme.of(context);

    return ListTile(
      selected: isSelected,
      leading: Icon(icon),
      title: Text(label),
      onTap: () => setState(() => _selectedTab = id),
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
      selectedColor: theme.colorScheme.primary,
    );
  }

  Widget _buildCategorySection(String category, List<Document> documents,
      {bool isCustom = false}) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category.toLowerCase();

    return ListTile(
      selected: isSelected,
      leading: Icon(
        getCategoryIcon(category),
        color: getCategoryColor(category),
      ),
      title: Text(getCategoryDisplayName(category)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${documents.length}'),
          if (isCustom)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _handleDeleteCategory(category),
            ),
        ],
      ),
      onTap: () => setState(() => _selectedCategory = category.toLowerCase()),
    );
  }

  Widget _buildMainContent(DocumentProvider provider) {
    if (_selectedTab == 'profile') return const ProfileTab();
    if (_selectedTab == 'settings') return SettingsTab();

    return Column(
      children: [
        const HomeQuickActionsBar(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDocumentGrid(provider),
        ),
      ],
    );
  }

  Widget _buildDocumentGrid(DocumentProvider provider) {
    final documents = _selectedCategory == 'all'
        ? provider.documents
        : provider.getDocumentsByCategory(_selectedCategory);

    if (documents.isEmpty) {
      return const Center(
        child: Text('No documents found'),
      );
    }

    return DocumentSection(
      title: _selectedCategory,
      documents: documents,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();

    return Scaffold(
      body: Row(
        children: [
          _buildSideNav(context, provider),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  title: Text(getCategoryDisplayName(_selectedCategory)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.upload_file),
                      onPressed: () =>
                          DocumentUploadingService.showUploadDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
                Expanded(
                  child: _buildMainContent(provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
