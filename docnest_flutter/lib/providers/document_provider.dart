// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';
import '../models/document.dart';
import '../services/document_service.dart';

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

  // Token Management
  void updateToken(String newToken) {
    _token = newToken;
    refreshDocuments();
    notifyListeners();
  }

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

  // Selection Methods
  void toggleSelection(String documentId) {
    if (_selectedDocuments.contains(documentId)) {
      _selectedDocuments.remove(documentId);
      if (_selectedDocuments.isEmpty) _isSelectionMode = false;
    } else {
      _isSelectionMode = true;
      _selectedDocuments.add(documentId);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedDocuments = _documents.map((doc) => doc.id).toSet();
    _isSelectionMode = true;
    notifyListeners();
  }

  void clearSelection() {
    _selectedDocuments.clear();
    _isSelectionMode = false;
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

  String getShareableContent() {
    if (selectedDocuments.isEmpty) return '';

    return selectedDocuments.map((doc) {
      return '''
Document: ${doc.name}
Category: ${doc.category}
Description: ${doc.description}
Created: ${doc.createdAt}
Modified: ${doc.modifiedAt}
''';
    }).join('\n---\n');
  }

  @override
  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    _searchHistory.clear();
    super.dispose();
  }
}
