import 'package:flutter/foundation.dart';
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

  final List<String> _defaultCategories = [
    'government',
    'medical',
    'educational',
    'other'
  ];
  Set<String> _customCategories = {};

  DocumentProvider({required String token}) : _token = token {
    if (_token.isNotEmpty) {
      _documentService = DocumentService(token: _token);
      // Don't call initialization here
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

  Future<void> initialize() async {
    if (_token.isEmpty) return;

    try {
      _isLoadingProfile = true;
      notifyListeners();

      // First fetch user profile
      await fetchUserProfile();

      // Then fetch documents
      await refreshDocuments();
    } catch (e) {
      print('Error initializing: $e');
      rethrow;
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserProfile() async {
    if (_token.isEmpty) {
      print('No token available for fetching profile');
      return;
    }

    try {
      final url = '${ApiConfig.authUrl}/me';
      print('Fetching profile from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(_token),
      );

      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = User.fromJson(userData);
        _customCategories = Set.from(
            (_currentUser?.customCategories ?? []).map((e) => e.toLowerCase()));
        print('Successfully loaded user profile');
      } else {
        throw Exception('Failed to load user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> _initializeData() async {
    try {
      await fetchUserProfile();
      await refreshDocuments();
    } catch (e) {
      print('Error initializing data: $e');
      // Don't rethrow here, let individual methods handle their errors
    }
  }

  Future<void> syncCategories() async {
    if (_token.isEmpty) {
      print('No token available for syncing categories');
      return;
    }

    try {
      print('Syncing categories with server...');
      final url = '${ApiConfig.authUrl}/me';
      final headers = {
        ...ApiConfig.authHeaders(_token),
        'Content-Type': 'application/json',
      };
      final body = json.encode(_customCategories.toList());

      print('Sending request to $url with headers: $headers and body: $body');
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('Sync categories response status: ${response.statusCode}');
      print('Sync categories response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to sync categories with server');
      }
    } catch (e) {
      print('Failed to sync categories with server: $e');
      rethrow;
    }
  }

  Future<bool> addCustomCategory(String category) async {
    final normalizedCategory = category.trim().toLowerCase();

    if (normalizedCategory.length < 2 ||
        _defaultCategories.contains(normalizedCategory) ||
        _customCategories.contains(normalizedCategory) ||
        _customCategories.length >= MAX_CUSTOM_CATEGORIES) {
      return false;
    }

    try {
      _customCategories.add(normalizedCategory);
      await syncCategories();
      notifyListeners();
      return true;
    } catch (e) {
      _customCategories.remove(normalizedCategory);
      rethrow;
    }
  }

  Future<bool> removeCustomCategory(String category) async {
    final normalizedCategory = category.toLowerCase();

    if (_defaultCategories.contains(normalizedCategory)) {
      return false;
    }

    final hasDocuments = _documents
        .any((doc) => doc.category.toLowerCase() == normalizedCategory);
    if (hasDocuments) {
      return false;
    }

    try {
      _customCategories.remove(normalizedCategory);
      await syncCategories();
      notifyListeners();
      return true;
    } catch (e) {
      _customCategories.add(normalizedCategory);
      rethrow;
    }
  }

  // Document Management
  void updateToken(String newToken) {
    _token = newToken;
    if (_token.isNotEmpty) {
      _documentService = DocumentService(token: _token);
      clearUserData();
      // Don't initialize here - let the UI control when to initialize
    } else {
      _documentService = null;
      clearUserData();
    }
    notifyListeners();
  }

  void clearUserData() {
    _currentUser = null;
    _customCategories.clear();
    _documents.clear();
    _selectedDocuments.clear();
    _searchHistory.clear();
    _isLoadingProfile = false;
    notifyListeners();
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

  void setDocuments(List<Document> documents) {
    _documents = documents;
    notifyListeners();
  }

  // Category Validation
  bool isDefaultCategory(String category) =>
      _defaultCategories.contains(category.toLowerCase());

  bool isCustomCategory(String category) =>
      _customCategories.contains(category.toLowerCase());

  bool isCategoryValid(String category) {
    final normalized = category.toLowerCase();
    return _defaultCategories.contains(normalized) ||
        _customCategories.contains(normalized);
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

  // Search Methods
  List<Document> searchDocuments(String query) {
    if (query.isEmpty) return [];
    final lowercaseQuery = query.toLowerCase();
    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(lowercaseQuery) ||
          doc.description.toLowerCase().contains(lowercaseQuery) ||
          doc.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

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

  void addDocument(Document document) {
    print(
        'Adding document: ${document.name} with category: ${document.category}');

    // Add document to list
    _documents.add(document);

    // If category is not a default category, ensure it's in custom categories
    final category = document.category.toLowerCase();
    if (!_defaultCategories.contains(category)) {
      _customCategories.add(category);
      // Sync categories with backend
      syncCategories();
    }

    notifyListeners();
  }

  Future<void> updateDocument(Document updatedDoc) async {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;

      // Update custom categories if needed
      final category = updatedDoc.category.toLowerCase();
      if (!_defaultCategories.contains(category)) {
        _customCategories.add(category);
        await syncCategories();
      }

      notifyListeners();
    }
  }

  Future<void> removeDocument(String id) async {
    try {
      if (_token.isEmpty) throw Exception('No authentication token available');

      await documentService.deleteDocument(id);

      // Remove from documents list
      _documents.removeWhere((doc) => doc.id == id);

      // Clear from selection if selected
      _selectedDocuments.remove(id);
      if (_selectedDocuments.isEmpty) {
        _isSelectionMode = false;
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Helper method to get documents by category
  List<Document> getDocumentsByCategory(String category) {
    return _documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();
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

  // Document Operations
  Future<void> updateDocumentCategory(
      String documentId, String newCategory) async {
    final normalizedCategory = newCategory.toLowerCase();
    if (!allCategories.contains(normalizedCategory)) {
      throw Exception('Invalid category');
    }

    try {
      final updatedDoc = await documentService.updateDocument(
        documentId: documentId,
        category: normalizedCategory,
      );

      final index = _documents.indexWhere((doc) => doc.id == documentId);
      if (index != -1) {
        _documents[index] = updatedDoc;
        notifyListeners();
      }
    } catch (e) {
      throw Exception('Failed to update document category: $e');
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

  @override
  void dispose() {
    clearUserData();
    super.dispose();
  }
}
