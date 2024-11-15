// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../models/user.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../utils/formatters.dart';

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDocuments = {};
  List<String> _searchHistory = [];
  static const int maxHistoryItems = 10;
  String _token;
  DocumentService? _documentService;
  bool _isDragging = false;
  User? _currentUser;
  bool _isLoadingProfile = false;

  // Category Management
  final List<String> _defaultCategories = [
    'government',
    'medical',
    'educational',
    'other'
  ];
  Set<String> _customCategories = {};
  final String _customCategoriesKey = 'user_custom_categories';
  SharedPreferences? _prefs;

  DocumentProvider({required String token}) : _token = token {
    if (_token.isNotEmpty) {
      _documentService = DocumentService(token: _token);
      _initializePreferences();
      refreshDocuments();
    }
  }

  // Getters
  List<Document> get documents => _documents;
  String get token => _token;
  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedDocuments.length;
  List<String> get searchHistory => _searchHistory;
  bool get isDragging => _isDragging;
  User? get currentUser => _currentUser;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get hasValidToken => _token.isNotEmpty;
  List<String> get defaultCategories => _defaultCategories;
  List<String> get customCategories => _customCategories.toList();
  List<String> get allCategories =>
      [..._defaultCategories, ..._customCategories];

  List<Document> get selectedDocuments =>
      _documents.where((doc) => _selectedDocuments.contains(doc.id)).toList();

  DocumentService get documentService {
    if (_documentService == null) {
      _documentService = DocumentService(token: _token);
    }
    return _documentService!;
  }

  // Category Management Methods
  Future<void> _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCustomCategories();
  }

  void _loadCustomCategories() {
    if (_prefs == null) return;
    final savedCategories = _prefs!.getStringList(_customCategoriesKey) ?? [];
    _customCategories = savedCategories.toSet();
    notifyListeners();
  }

  Future<void> _saveCustomCategories() async {
    if (_prefs == null) return;
    await _prefs!
        .setStringList(_customCategoriesKey, _customCategories.toList());
  }

  Future<bool> addCustomCategory(String category) async {
    final normalizedCategory = category.trim().toLowerCase();

    if (normalizedCategory.isEmpty) {
      return false;
    }

    if (_defaultCategories.contains(normalizedCategory) ||
        _customCategories.contains(normalizedCategory)) {
      return false;
    }

    _customCategories.add(normalizedCategory);
    await _saveCustomCategories();
    notifyListeners();

    if (currentUser != null) {
      try {
        // TODO: Add API call to save category on backend
        // await _documentService.addCustomCategory(normalizedCategory);
      } catch (e) {
        print('Failed to sync category with backend: $e');
      }
    }

    return true;
  }

  Future<bool> removeCustomCategory(String category) async {
    if (_defaultCategories.contains(category)) {
      return false;
    }

    final success = _customCategories.remove(category);
    if (success) {
      await _saveCustomCategories();
      notifyListeners();

      if (currentUser != null) {
        try {
          // TODO: Add API call to remove category on backend
          // await _documentService.removeCustomCategory(category);
        } catch (e) {
          print('Failed to sync category removal with backend: $e');
        }
      }
    }
    return success;
  }

  bool isDefaultCategory(String category) {
    return _defaultCategories.contains(category.toLowerCase());
  }

  bool isCustomCategory(String category) {
    return _customCategories.contains(category.toLowerCase());
  }

  // Selection Methods
  bool isSelected(String documentId) => _selectedDocuments.contains(documentId);

  void startSelection() {
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedDocuments.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void toggleSelection(String documentId) {
    if (_selectedDocuments.contains(documentId)) {
      _selectedDocuments.remove(documentId);
      if (_selectedDocuments.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedDocuments.add(documentId);
      _isSelectionMode = true;
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedDocuments = _documents.map((doc) => doc.id).toSet();
    _isSelectionMode = true;
    notifyListeners();
  }

  // Document Management
  void updateToken(String newToken) {
    _token = newToken;
    if (_token.isNotEmpty) {
      _documentService = DocumentService(token: _token);
      refreshDocuments();
    } else {
      _documentService = null;
    }
    notifyListeners();
  }

  void setDocuments(List<Document> documents) {
    _documents = documents;
    if (currentUser != null && currentUser!.customCategories.isNotEmpty) {
      _customCategories = Set.from(currentUser!.customCategories);
      _saveCustomCategories();
    }
    notifyListeners();
  }

  void addDocument(Document document) {
    _documents.add(document);
    notifyListeners();
  }

  void updateDocument(Document updatedDoc) {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;
      notifyListeners();
    }
  }

  Future<void> removeDocument(String id) async {
    try {
      if (_token.isEmpty) throw Exception('No authentication token available');
      await documentService.deleteDocument(id);
      _documents.removeWhere((doc) => doc.id == id);
      _selectedDocuments.remove(id);
      if (_selectedDocuments.isEmpty) _isSelectionMode = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  void reorderDocuments(String category, int oldIndex, int newIndex) {
    final categoryDocs = _documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();

    if (oldIndex < categoryDocs.length && newIndex < categoryDocs.length) {
      final doc = categoryDocs.removeAt(oldIndex);
      categoryDocs.insert(newIndex, doc);

      _documents = _documents.map((d) {
        if (d.category.toLowerCase() != category.toLowerCase()) return d;
        return categoryDocs[categoryDocs.indexOf(d)];
      }).toList();

      notifyListeners();
    }
  }

  // Drag and Drop
  void startDragging() {
    _isDragging = true;
    notifyListeners();
  }

  void endDragging() {
    _isDragging = false;
    notifyListeners();
  }

  // Search Methods
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > maxHistoryItems) {
      _searchHistory = _searchHistory.take(maxHistoryItems).toList();
    }
    notifyListeners();
  }

  void removeFromSearchHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  List<Document> searchDocuments(String query) {
    if (query.isEmpty) return [];
    final lowercaseQuery = query.toLowerCase();
    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(lowercaseQuery) ||
          doc.description.toLowerCase().contains(lowercaseQuery) ||
          doc.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<void> refreshDocuments() async {
    try {
      if (_token.isEmpty) return;
      final docs = await documentService.getDocuments();
      setDocuments(docs);
    } catch (e) {
      print('Error refreshing documents: $e');
      rethrow;
    }
  }

  // Category Update
  Future<void> updateDocumentCategory(
      String documentId, String newCategory) async {
    final normalizedCategory = newCategory.toLowerCase();
    if (!allCategories.contains(normalizedCategory)) {
      throw Exception('Invalid category');
    }

    try {
      if (_token.isEmpty) throw Exception('No authentication token available');
      final updatedDoc = await documentService.updateDocument(
        documentId: documentId,
        category: normalizedCategory,
      );
      updateDocument(updatedDoc);
    } catch (e) {
      throw Exception('Failed to update document category: $e');
    }
  }

  // Profile Management
  Future<void> fetchUserProfile() async {
    if (_token.isEmpty) {
      print('No token available for fetching profile');
      return;
    }
    if (_isLoadingProfile) {
      print('Already loading profile');
      return;
    }

    try {
      _isLoadingProfile = true;
      notifyListeners();

      final url = '${ApiConfig.authUrl}/me';
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(_token),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = User.fromJson(userData);

        // Load custom categories from user profile
        if (_currentUser!.customCategories.isNotEmpty) {
          _customCategories = Set.from(_currentUser!.customCategories);
          _saveCustomCategories();
        }
      } else {
        throw Exception('Failed to load user profile');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  // Sync categories with backend
  Future<void> syncCategories() async {
    if (currentUser != null && _token.isNotEmpty) {
      try {
        // TODO: Add API call to sync categories
        // final serverCategories = await _documentService.getUserCategories();
        // _customCategories = Set.from(serverCategories);
        await _saveCustomCategories();
        notifyListeners();
      } catch (e) {
        print('Failed to sync categories with server: $e');
      }
    }
  }

  String getShareableContent() {
    if (_selectedDocuments.isEmpty) return '';

    return _documents
        .where((doc) => _selectedDocuments.contains(doc.id))
        .map((doc) => '''
Document: ${doc.name}
Category: ${doc.category}
Description: ${doc.description ?? 'No description'}
Created: ${formatDate(doc.createdAt)}
''')
        .join('\n---\n');
  }

  void markAsShared(List<String> documentIds) {
    for (final id in documentIds) {
      final index = _documents.indexWhere((doc) => doc.id == id);
      if (index != -1) {
        final updatedDoc = _documents[index].copyWith(isShared: true);
        _documents[index] = updatedDoc;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    _searchHistory.clear();
    _customCategories.clear();
    super.dispose();
  }
}
