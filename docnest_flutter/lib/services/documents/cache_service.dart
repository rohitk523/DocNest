// lib/services/cache_service.dart

import 'package:flutter/foundation.dart';

import '../../mobile/services/mobile_cache_service.dart';
import '../../web/services/web_cache_service.dart';

abstract class BaseCacheService {
  Future<void> cacheDocumentWithName(String fileName, List<int> bytes);
  Future<dynamic> getCachedDocumentByName(String fileName);
  Future<bool> hasValidCache(String filePath, String fileType);
  Future<void> saveToCache(String filePath, String fileType, List<int> bytes);
  Future<void> savePreview(String filePath, String fileType, List<int> bytes);
  Future<dynamic> getFromCache(String filePath, String fileType);
  Future<dynamic> getPreview(String filePath);
  Future<void> clearCache();
}

class CacheService implements BaseCacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;

  late final BaseCacheService _implementation;

  CacheService._internal() {
    _implementation = kIsWeb ? WebCacheService() : MobileCacheService();
  }

  @override
  Future<void> cacheDocumentWithName(String fileName, List<int> bytes) =>
      _implementation.cacheDocumentWithName(fileName, bytes);

  @override
  Future<dynamic> getCachedDocumentByName(String fileName) =>
      _implementation.getCachedDocumentByName(fileName);

  @override
  Future<bool> hasValidCache(String filePath, String fileType) =>
      _implementation.hasValidCache(filePath, fileType);

  @override
  Future<void> saveToCache(String filePath, String fileType, List<int> bytes) =>
      _implementation.saveToCache(filePath, fileType, bytes);

  @override
  Future<void> savePreview(String filePath, String fileType, List<int> bytes) =>
      _implementation.savePreview(filePath, fileType, bytes);

  @override
  Future<dynamic> getFromCache(String filePath, String fileType) =>
      _implementation.getFromCache(filePath, fileType);

  @override
  Future<dynamic> getPreview(String filePath) =>
      _implementation.getPreview(filePath);

  @override
  Future<void> clearCache() => _implementation.clearCache();
}
