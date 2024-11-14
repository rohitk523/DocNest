import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<String> get _cacheDir async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/document_previews');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<String> _generateCacheKey(String filePath, String fileType) async {
    final keyData = utf8.encode('$filePath-$fileType');
    final hash = md5.convert(keyData);
    return hash.toString();
  }

  Future<File> _getCacheFile(String key) async {
    final dir = await _cacheDir;
    return File('$dir/$key.cache');
  }

  Future<bool> hasValidCache(String filePath, String fileType) async {
    try {
      final key = await _generateCacheKey(filePath, fileType);
      final cacheFile = await _getCacheFile(key);
      if (!await cacheFile.exists()) return false;

      // Check if cache is older than 24 hours
      final lastModified = await cacheFile.lastModified();
      final difference = DateTime.now().difference(lastModified);
      return difference.inHours < 24;
    } catch (e) {
      print('Cache validation error: $e');
      return false;
    }
  }

  Future<Uint8List?> getFromCache(String filePath, String fileType) async {
    try {
      final key = await _generateCacheKey(filePath, fileType);
      final cacheFile = await _getCacheFile(key);
      if (await cacheFile.exists()) {
        return await cacheFile.readAsBytes();
      }
    } catch (e) {
      print('Cache read error: $e');
    }
    return null;
  }

  Future<void> saveToCache(
      String filePath, String fileType, Uint8List bytes) async {
    try {
      final key = await _generateCacheKey(filePath, fileType);
      final cacheFile = await _getCacheFile(key);
      await cacheFile.writeAsBytes(bytes);
    } catch (e) {
      print('Cache write error: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      final cacheDir = Directory(dir);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Cache clear error: $e');
    }
  }
}
