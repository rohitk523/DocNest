// lib/providers/document_provider.dart
import 'package:flutter/foundation.dart';

class Document {
  final String id;
  final String name;
  final String content;
  final String? path;
  final String category;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isShared; // New field to track sharing status

  Document({
    required this.id,
    required this.name,
    required this.content,
    this.path,
    required this.category,
    required this.createdAt,
    required this.modifiedAt,
    this.isShared = false, // Default value
  });

  // Clone method with optional parameter overrides
  Document copyWith({
    String? id,
    String? name,
    String? content,
    String? path,
    String? category,
    DateTime? createdAt,
    DateTime? modifiedAt,
    bool? isShared,
  }) {
    return Document(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      path: path ?? this.path,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      isShared: isShared ?? this.isShared,
    );
  }

  // Convert document to a shareable format
  Map<String, dynamic> toShareableFormat() {
    return {
      'name': name,
      'content': content,
      'category': category,
      'created': createdAt.toIso8601String(),
      'modified': modifiedAt.toIso8601String(),
    };
  }
}

class DocumentProvider with ChangeNotifier {
  List<Document> _documents = [];
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedDocuments = {};

  // Getters
  List<Document> get documents => _documents;
  String get searchQuery => _searchQuery;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedDocuments => _selectedDocuments;
  int get selectedCount => _selectedDocuments.length;

  // Get selected document objects
  List<Document> get selectedDocumentObjects {
    return _documents
        .where((doc) => _selectedDocuments.contains(doc.id))
        .toList();
  }

  // Get filtered documents
  List<Document> get filteredDocuments {
    if (_searchQuery.isEmpty) return _documents;
    final query = _searchQuery.toLowerCase();
    return _documents.where((doc) {
      return doc.name.toLowerCase().contains(query) ||
          doc.content.toLowerCase().contains(query) ||
          doc.category.toLowerCase().contains(query);
    }).toList();
  }

  // Toggle selection mode
  void toggleSelectionMode() {
    _isSelectionMode = !_isSelectionMode;
    if (!_isSelectionMode) {
      clearSelection();
    }
    notifyListeners();
  }

  // Toggle document selection
  void toggleDocumentSelection(String documentId) {
    if (!_isSelectionMode) {
      _isSelectionMode = true;
    }

    if (_selectedDocuments.contains(documentId)) {
      _selectedDocuments.remove(documentId);
      if (_selectedDocuments.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedDocuments.add(documentId);
    }
    notifyListeners();
  }

  // Select all documents
  void selectAllDocuments() {
    _selectedDocuments = filteredDocuments.map((doc) => doc.id).toSet();
    _isSelectionMode = _selectedDocuments.isNotEmpty;
    notifyListeners();
  }

  // Clear selection
  void clearSelection() {
    _selectedDocuments.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  // Check if document is selected
  bool isDocumentSelected(String documentId) {
    return _selectedDocuments.contains(documentId);
  }

  // Add document
  void addDocument(Document document) {
    _documents.add(document);
    notifyListeners();
  }

  // Remove document
  void removeDocument(String id) {
    _documents.removeWhere((doc) => doc.id == id);
    _selectedDocuments.remove(id);
    if (_selectedDocuments.isEmpty) {
      _isSelectionMode = false;
    }
    notifyListeners();
  }

  // Remove selected documents
  void removeSelectedDocuments() {
    _documents.removeWhere((doc) => _selectedDocuments.contains(doc.id));
    clearSelection();
  }

  // Update document
  void updateDocument(Document updatedDoc) {
    final index = _documents.indexWhere((doc) => doc.id == updatedDoc.id);
    if (index != -1) {
      _documents[index] = updatedDoc;
      notifyListeners();
    }
  }

  // Mark documents as shared
  void markDocumentsAsShared(List<String> documentIds) {
    for (final id in documentIds) {
      final index = _documents.indexWhere((doc) => doc.id == id);
      if (index != -1) {
        _documents[index] = _documents[index].copyWith(isShared: true);
      }
    }
    notifyListeners();
  }

  // Search functionality
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  // Load documents (mock data)
  Future<void> loadDocuments() async {
    _documents = [
      Document(
        id: '1',
        name: 'Health Insurance Policy',
        content: 'Health insurance details and coverage information.',
        category: 'Medical',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
      Document(
        id: '2',
        name: 'College Transcript',
        content: 'Academic transcript from university.',
        category: 'Educational',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
      Document(
        id: '3',
        name: 'Tax Return 2023',
        content: 'Annual tax return documentation.',
        category: 'Finance',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  // Get sharable content for selected documents
  String getShareableContent() {
    final selectedDocs = selectedDocumentObjects;
    if (selectedDocs.isEmpty) return '';

    return selectedDocs.map((doc) {
      return '''
Document: ${doc.name}
Category: ${doc.category}
Content: ${doc.content}
Created: ${doc.createdAt.toString()}
Modified: ${doc.modifiedAt.toString()}
''';
    }).join('\n---\n');
  }
}
