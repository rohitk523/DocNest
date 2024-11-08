// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';
import '../models/document.dart';

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDocuments = {};

  // Getters
  List<Document> get documents => _documents;
  List<Document> get selectedDocuments =>
      _documents.where((doc) => _selectedDocuments.contains(doc.id)).toList();
  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedDocuments.length;

  // Get documents by category
  List<Document> getDocumentsByCategory(String category) {
    return _documents
        .where((doc) => doc.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Search documents
  List<Document> searchDocuments(String query) {
    if (query.isEmpty) return _documents;
    final lowercaseQuery = query.toLowerCase();
    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(lowercaseQuery) ||
          doc.description.toLowerCase().contains(lowercaseQuery) ||
          doc.category.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Selection methods
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

  // Document operations
  void setDocuments(List<Document> documents) {
    _documents = documents;
    notifyListeners();
  }

  void addDocument(Document document) {
    _documents.add(document);
    notifyListeners();
  }

  void removeDocument(String id) {
    _documents.removeWhere((doc) => doc.id == id);
    _selectedDocuments.remove(id);
    if (_selectedDocuments.isEmpty) _isSelectionMode = false;
    notifyListeners();
  }

  void removeSelectedDocuments() {
    _documents.removeWhere((doc) => _selectedDocuments.contains(doc.id));
    clearSelection();
  }

  void updateDocument(Document updatedDoc) {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;
      notifyListeners();
    }
  }

  // Sharing functionality
  void markAsShared(List<String> documentIds) {
    for (final id in documentIds) {
      final index = _documents.indexWhere((doc) => doc.id == id);
      if (index != -1) {
        _documents[index] = _documents[index].copyWith(isShared: true);
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

  void dispose() {
    _documents.clear();
    _selectedDocuments.clear();
    super.dispose();
  }
}
