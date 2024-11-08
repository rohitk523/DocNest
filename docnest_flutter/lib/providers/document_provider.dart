// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';
import '../models/document.dart';

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDocuments = {};
  List<String> _searchHistory = [];
  static const int maxHistoryItems = 10;

  // Getters
  List<Document> get documents => _documents;
  List<Document> get selectedDocuments =>
      _documents.where((doc) => _selectedDocuments.contains(doc.id)).toList();
  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedDocuments.length;
  List<String> get searchHistory => _searchHistory;

  // Search History Methods
  void addToSearchHistory(String query) {
    if (query.trim().isEmpty) return;

    // Remove if exists (to avoid duplicates) and add to front
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);

    // Keep only the last N items
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
      // Here you would typically call your API to delete the documents
      _documents.removeWhere((doc) => _selectedDocuments.contains(doc.id));
      _selectedDocuments.clear();
      _isSelectionMode = false;
      notifyListeners();
    } catch (e) {
      // Re-throw the error to be handled by the UI
      throw Exception('Failed to delete documents: $e');
    }
  }

  void removeDocument(String id) {
    _documents.removeWhere((doc) => doc.id == id);
    _selectedDocuments.remove(id);
    if (_selectedDocuments.isEmpty) _isSelectionMode = false;
    notifyListeners();
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
        // Since Document is immutable, we need to create a new instance
        // This assumes Document has a copyWith method
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
