// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../models/user.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDocuments = {};
  List<String> _searchHistory = [];
  static const int maxHistoryItems = 10;
  String _token;

  DocumentProvider({required String token}) : _token = token {
    if (_token.isNotEmpty) {
      refreshDocuments();
    }
  }

  // Getters
  List<Document> get documents => _documents;
  List<Document> get selectedDocuments =>
      _documents.where((doc) => _selectedDocuments.contains(doc.id)).toList();
  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedDocuments.length;
  List<String> get searchHistory => _searchHistory;
  String get token => _token;
  // Add this to your DocumentProvider class
  bool _isDragging = false;
  bool get isDragging => _isDragging;

  void startDragging() {
    _isDragging = true;
    notifyListeners();
  }

  void endDragging() {
    _isDragging = false;
    notifyListeners();
  }

  void startSelection() {
    _isSelectionMode = true;
    notifyListeners();
  }

  // Just to make sure all related methods are properly defined
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

  // Update your getShareableContent method if not already present
  String getShareableContent() {
    if (_selectedDocuments.isEmpty) return '';

    return _documents
        .where((doc) => _selectedDocuments.contains(doc.id))
        .map((doc) => '''
Document: ${doc.name}
Category: ${doc.category}
Description: ${doc.description}
Created: ${doc.createdAt}
''')
        .join('\n---\n');
  }

  User? _currentUser;
  User? get currentUser => _currentUser;

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
      print('Fetching user profile...');
      _isLoadingProfile = true;
      notifyListeners();

      final url = '${ApiConfig.authUrl}/me';
      print('Request URL: $url');
      print('Request headers: ${ApiConfig.authHeaders(_token)}');

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConfig.authHeaders(_token),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = User.fromJson(userData);
        print('Successfully loaded user profile: ${_currentUser?.email}');
      } else {
        print('Failed to load profile: ${response.statusCode}');
        print('Response body: ${response.body}');
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

// Update the updateToken method to also fetch user profile
  void updateTokenProfile(String newToken) {
    _token = newToken;
    if (_token.isNotEmpty) {
      fetchUserProfile();
    }
    notifyListeners();
  }

  // Token Management
  void updateToken(String newToken) {
    print('Updating token from: $_token');
    print('Updating token to: $newToken');
    _token = newToken;
    if (_token.isNotEmpty) {
      refreshDocuments();
    }
    notifyListeners();
  }

  bool get hasValidToken => _token.isNotEmpty;

  Future<void> refreshDocuments() async {
    try {
      if (_token.isEmpty) return;
      final documentService = DocumentService(token: _token);
      final docs = await documentService.getDocuments();
      setDocuments(docs);
    } catch (e) {
      print('Error refreshing documents: $e');
    }
  }

  // Search History Methods
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    _searchHistory.remove(query);
    _searchHistory.insert(0, query);

    if (_searchHistory.length > maxHistoryItems) {
      _searchHistory = _searchHistory.take(maxHistoryItems).toList();
    }

    notifyListeners();
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  void removeFromSearchHistory(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  // Document Search
  List<Document> searchDocuments(String query) {
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();
    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(lowercaseQuery) ||
          doc.description.toLowerCase().contains(lowercaseQuery) ||
          doc.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  void selectAll() {
    _selectedDocuments = _documents.map((doc) => doc.id).toSet();
    _isSelectionMode = true;
    notifyListeners();
  }

  bool isSelected(String documentId) => _selectedDocuments.contains(documentId);

  // Document Operations
  void setDocuments(List<Document> documents) {
    _documents = documents;
    notifyListeners();
  }

  void addDocument(Document document) {
    _documents.add(document);
    notifyListeners();
  }

  void reorderDocuments(String category, int oldIndex, int newIndex) {
    final categoryDocs = _documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();

    if (oldIndex < categoryDocs.length && newIndex < categoryDocs.length) {
      final doc = categoryDocs.removeAt(oldIndex);
      categoryDocs.insert(newIndex, doc);

      // Update the main documents list to match the new order
      _documents = _documents.map((d) {
        if (d.category.toLowerCase() != category.toLowerCase()) return d;
        return categoryDocs[categoryDocs.indexOf(d)];
      }).toList();

      notifyListeners();
    }
  }

  Future<void> removeSelectedDocuments() async {
    try {
      if (_token.isEmpty) throw Exception('No authentication token available');
      final documentService = DocumentService(token: _token);

      for (final documentId in _selectedDocuments) {
        await documentService.deleteDocument(documentId);
      }

      _documents.removeWhere((doc) => _selectedDocuments.contains(doc.id));
      _selectedDocuments.clear();
      _isSelectionMode = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete documents: $e');
    }
  }

  Future<void> removeDocument(String id) async {
    try {
      if (_token.isEmpty) throw Exception('No authentication token available');
      final documentService = DocumentService(token: _token);

      await documentService.deleteDocument(id);

      _documents.removeWhere((doc) => doc.id == id);
      _selectedDocuments.remove(id);
      if (_selectedDocuments.isEmpty) _isSelectionMode = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  void updateDocument(Document updatedDoc) {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;
      notifyListeners();
    }
  }

  Future<void> updateDocumentCategory(
      String documentId, String newCategory) async {
    try {
      final documentService = DocumentService(token: token);
      final updatedDoc = await documentService.updateDocument(
        documentId: documentId,
        category: newCategory,
      );
      updateDocument(updatedDoc);
    } catch (e) {
      throw Exception('Failed to update document category: $e');
    }
  }

  // Sharing Functionality
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

  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;

  @override
  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    _searchHistory.clear();
    super.dispose();
  }
}
