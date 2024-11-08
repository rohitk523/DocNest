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

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({Key? key, required this.token}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1;
  bool _isLoading = true;
  late DocumentService _documentService;

  final List<String> _categories = [
    'Government',
    'Medical',
    'Educational',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _documentService = DocumentService(token: widget.token);
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    try {
      setState(() => _isLoading = true);
      final docs = await _documentService.getDocuments();

      // Update the DocumentProvider with the loaded documents
      if (mounted) {
        context.read<DocumentProvider>().setDocuments(docs);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading documents: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Document> _getDocumentsByCategory(String category) {
    final provider = context.read<DocumentProvider>();
    return provider.documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const QuickActionsBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadDocuments,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final categoryDocuments = _getDocumentsByCategory(category);

                if (categoryDocuments.isEmpty) {
                  return Container(); // Skip empty categories
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
          SettingsTab(onLogout: () {
            // TODO: Implement logout
          }),
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
              onPressed: _handleUpload,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _handleUpload() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UploadDocumentDialog(),
    );

    if (result != null) {
      try {
        final uploadedDoc = await _documentService.uploadDocument(
          name: result['name'],
          description: result['description'],
          category: result['category'],
          file: result['file'],
        );

        if (mounted) {
          context.read<DocumentProvider>().addDocument(uploadedDoc);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading document: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
