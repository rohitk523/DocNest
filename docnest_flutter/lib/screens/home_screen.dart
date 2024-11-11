// lib/screens/home_screen.dart
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

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({Key? key, required this.token}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDocuments,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _categories.length,
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
          ),
        ),
      ],
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
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ProfileTab(),
          _buildHomeContent(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: _handleUpload,
            )
          : null,
    );
  }
}
