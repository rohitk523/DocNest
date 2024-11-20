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
  static const int MAX_CUSTOM_CATEGORIES = 20;

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

  void _debugPrintCategories() {
    print('Default categories: $_defaultCategories');
    print('Custom categories: $_customCategories');
    print('All categories: ${[..._defaultCategories, ..._customCategories]}');
  }

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

  List<String> get defaultCategories {
    _debugPrintCategories();
    return _defaultCategories;
  }

  List<String> get customCategories {
    _debugPrintCategories();
    return _customCategories.toList();
  }

  List<String> get allCategories {
    _debugPrintCategories();
    final all = [..._defaultCategories, ..._customCategories];
    print('Returning all categories: $all');
    return all;
  }

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
    await _loadCustomCategories();
    _debugPrintCategories();
  }

  Future<void> _loadCustomCategories() async {
    if (_prefs == null) return;
    final savedCategories = _prefs!.getStringList(_customCategoriesKey) ?? [];
    print('Loading saved categories: $savedCategories');
    _customCategories = savedCategories.map((e) => e.toLowerCase()).toSet();
    notifyListeners();
  }

  Future<void> _saveCustomCategories() async {
    if (_prefs == null) return;
    final categoriesToSave = _customCategories.toList();
    print('Saving categories: $categoriesToSave');
    await _prefs!.setStringList(_customCategoriesKey, categoriesToSave);
  }

  Future<bool> addCustomCategory(String category) async {
    final normalizedCategory = category.trim().toLowerCase();
    print('Adding custom category: $normalizedCategory');

    if (normalizedCategory.isEmpty || normalizedCategory.length < 2) {
      print('Invalid category name: too short');
      return false;
    }

    if (_defaultCategories.contains(normalizedCategory)) {
      print('Category is a default category');
      return false;
    }

    if (_customCategories.contains(normalizedCategory)) {
      print('Category already exists in custom categories');
      return false;
    }

    if (_customCategories.length >= MAX_CUSTOM_CATEGORIES) {
      print('Maximum number of custom categories reached');
      return false;
    }

    _customCategories.add(normalizedCategory);
    await _saveCustomCategories();
    _debugPrintCategories();
    notifyListeners();

    return true;
  }

  Future<bool> removeCustomCategory(String category) async {
    final normalizedCategory = category.toLowerCase();
    print('Removing custom category: $normalizedCategory');

    if (_defaultCategories.contains(normalizedCategory)) {
      print('Cannot remove default category');
      return false;
    }

    // Check if category is in use
    final hasDocuments = _documents
        .any((doc) => doc.category.toLowerCase() == normalizedCategory);

    if (hasDocuments) {
      print('Cannot remove category that has documents');
      return false;
    }

    final success = _customCategories.remove(normalizedCategory);
    if (success) {
      await _saveCustomCategories();
      _debugPrintCategories();
      notifyListeners();
    }
    return success;
  }

  bool isDefaultCategory(String category) {
    final isDefault = _defaultCategories.contains(category.toLowerCase());
    print('Checking if $category is default: $isDefault');
    return isDefault;
  }

  bool isCustomCategory(String category) {
    final isCustom = _customCategories.contains(category.toLowerCase());
    print('Checking if $category is custom: $isCustom');
    return isCustom;
  }

  bool isCategoryValid(String category) {
    final normalized = category.toLowerCase();
    final isValid = _defaultCategories.contains(normalized) ||
        _customCategories.contains(normalized);
    print('Validating category $category: $isValid');
    return isValid;
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
    print('Setting documents: ${documents.length}');
    _documents = documents;

    if (currentUser != null && currentUser!.customCategories.isNotEmpty) {
      print('Loading custom categories from user profile');
      _customCategories =
          Set.from(currentUser!.customCategories.map((e) => e.toLowerCase()));
      _saveCustomCategories();
    }

    // Extract unique categories from documents
    final documentCategories = documents
        .map((doc) => doc.category.toLowerCase())
        .where((category) => !_defaultCategories.contains(category))
        .toSet();

    print('Found categories in documents: $documentCategories');
    _customCategories.addAll(documentCategories);
    _saveCustomCategories();

    _debugPrintCategories();
    notifyListeners();
  }

  void addDocument(Document document) {
    print(
        'Adding document: ${document.name} with category: ${document.category}');
    final category = document.category.toLowerCase();

    if (!_defaultCategories.contains(category)) {
      _customCategories.add(category);
      _saveCustomCategories();
    }

    _documents.add(document);
    _debugPrintCategories();
    notifyListeners();
  }

  void updateDocument(Document updatedDoc) {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      print(
          'Updating document: ${updatedDoc.name} with category: ${updatedDoc.category}');
      _documents[index] = updatedDoc;

      // Update custom categories if needed
      final category = updatedDoc.category.toLowerCase();
      if (!_defaultCategories.contains(category)) {
        _customCategories.add(category);
        _saveCustomCategories();
      }

      _debugPrintCategories();
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

        // Update custom categories from user profile
        _customCategories = Set.from(
            _currentUser!.customCategories.map((e) => e.toLowerCase()));

        // No need to save to SharedPreferences anymore since categories come from backend
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
