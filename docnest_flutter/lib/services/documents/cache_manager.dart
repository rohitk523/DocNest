import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/document.dart';
import './cache_service.dart';

/// CacheManager works alongside CacheService to handle document metadata caching
/// while CacheService continues to handle file and preview caching
class CacheManager {
  static CacheManager? _instance;
  late final SharedPreferences _prefs;
  final CacheService _cacheService = CacheService();

  static const String _documentMetadataKey = 'cached_documents_metadata';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // In-memory cache of document metadata
  final Map<String, Document> _documentCache = {};

  // Private constructor
  CacheManager._();

  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      _instance = CacheManager._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final String? metadata = _prefs.getString(_documentMetadataKey);
      if (metadata != null) {
        final List<dynamic> documents = json.decode(metadata);
        _documentCache.clear();
        for (var doc in documents) {
          try {
            final document = Document.fromJson(doc);
            _documentCache[document.id] = document;
          } catch (e) {
            debugPrint('Error parsing cached document metadata: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cache metadata: $e');
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final documentsJson =
          _documentCache.values.map((doc) => doc.toJson()).toList();
      await _prefs.setString(_documentMetadataKey, json.encode(documentsJson));
      await _prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving cache metadata: $e');
    }
  }

  Future<void> cacheDocument(Document document, List<int>? fileData) async {
    // Update metadata cache
    _documentCache[document.id] = document;
    await _saveMetadata();

    // If we have file data, use CacheService to cache it
    if (fileData != null &&
        document.filePath != null &&
        document.fileType != null) {
      await _cacheService.saveToCache(
          document.filePath!, document.fileType!, fileData);
      await _cacheService.savePreview(
          document.filePath!, document.fileType!, fileData);
    }
  }

  Future<bool> hasCachedDocument(String documentId) async {
    return _documentCache.containsKey(documentId);
  }

  Future<Document?> getCachedDocument(String documentId) async {
    return _documentCache[documentId];
  }

  Future<List<Document>> getCachedDocuments() async {
    return _documentCache.values.toList();
  }

  bool isCacheStale(Document document) {
    final cachedDoc = _documentCache[document.id];
    if (cachedDoc == null) return true;

    return cachedDoc.version != document.version ||
        cachedDoc.modifiedAt != document.modifiedAt;
  }

  Future<void> removeDocument(String documentId) async {
    // Remove from metadata cache
    _documentCache.remove(documentId);
    await _saveMetadata();
  }

  Future<void> clear() async {
    // Clear metadata cache
    _documentCache.clear();
    await _prefs.remove(_documentMetadataKey);
    await _prefs.remove(_lastSyncKey);

    // Clear file cache using existing CacheService
    await _cacheService.clearCache();
  }

  // Helper method to check if we need to sync with server
  Future<bool> needsSync() async {
    final lastSync = _prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Sync if more than 30 minutes have passed
    return (now - lastSync) > const Duration(minutes: 30).inMilliseconds;
  }
}
