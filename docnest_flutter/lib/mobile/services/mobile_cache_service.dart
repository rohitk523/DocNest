// lib/services/cache/mobile_cache_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../services/documents/cache_service.dart';

class MobileCacheService implements BaseCacheService {
  static final MobileCacheService _instance = MobileCacheService._internal();
  factory MobileCacheService() => _instance;
  MobileCacheService._internal();

  static const int PREVIEW_WIDTH = 200;
  static const int PREVIEW_HEIGHT = 280;
  static const Duration CACHE_DURATION = Duration(days: 7);

  Future<String> get _cacheDir async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/document_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<String> get _previewDir async {
    final dir = await getTemporaryDirectory();
    final previewDir = Directory('${dir.path}/preview_cache');
    if (!await previewDir.exists()) {
      await previewDir.create(recursive: true);
    }
    return previewDir.path;
  }

  Future<String> get _documentsDir async {
    final dir = await getApplicationDocumentsDirectory();
    final docsDir = Directory('${dir.path}/cached_documents');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir.path;
  }

  String _generateCacheKey(String filePath) {
    return md5.convert(utf8.encode(filePath)).toString();
  }

  @override
  Future<void> cacheDocumentWithName(String fileName, List<int> bytes) async {
    try {
      final docsDir = await _documentsDir;
      final file = File('$docsDir/$fileName');
      await file.writeAsBytes(bytes);
    } catch (e) {
      print('Error caching document: $e');
    }
  }

  @override
  Future<File?> getCachedDocumentByName(String fileName) async {
    try {
      final docsDir = await _documentsDir;
      final file = File('$docsDir/$fileName');
      if (await file.exists()) {
        return file;
      }
    } catch (e) {
      print('Error getting cached document: $e');
    }
    return null;
  }

  @override
  Future<bool> hasValidCache(String filePath, String fileType) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final cacheFile = File('${await _cacheDir}/$cacheKey');
      final previewFile = File('${await _previewDir}/${cacheKey}_preview.png');

      if (!await cacheFile.exists() || !await previewFile.exists()) {
        return false;
      }

      final cacheStats = await cacheFile.stat();
      final previewStats = await previewFile.stat();
      final now = DateTime.now();

      return now.difference(cacheStats.modified) < CACHE_DURATION &&
          now.difference(previewStats.modified) < CACHE_DURATION;
    } catch (e) {
      print('Cache validation error: $e');
      return false;
    }
  }

  @override
  Future<void> saveToCache(
      String filePath, String fileType, List<int> bytes) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final cacheFile = File('${await _cacheDir}/$cacheKey');
      await cacheFile.writeAsBytes(bytes);
    } catch (e) {
      print('Cache write error: $e');
    }
  }

  @override
  Future<void> savePreview(
      String filePath, String fileType, List<int> bytes) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final previewFile = File('${await _previewDir}/${cacheKey}_preview.png');

      Uint8List? previewBytes;
      final uint8Bytes = Uint8List.fromList(bytes);

      if (fileType.startsWith('application/pdf')) {
        previewBytes = await _generatePdfPreview(uint8Bytes);
      } else if (fileType.startsWith('image/')) {
        previewBytes = await _generateImagePreview(uint8Bytes);
      }

      if (previewBytes != null) {
        await previewFile.writeAsBytes(previewBytes);
      }
    } catch (e) {
      print('Preview generation error: $e');
    }
  }

  Future<Uint8List?> _generatePdfPreview(Uint8List bytes) async {
    try {
      final document = await PdfDocument.openData(bytes);
      final firstPage = await document.getPage(1);
      final pageImage = await firstPage.render(
        width: PREVIEW_WIDTH,
        height: PREVIEW_HEIGHT,
      );
      final image = await pageImage.createImageDetached();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      await document.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('PDF preview generation error: $e');
      return null;
    }
  }

  Future<Uint8List?> _generateImagePreview(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: PREVIEW_WIDTH,
        targetHeight: PREVIEW_HEIGHT,
      );
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Image preview generation error: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> getFromCache(String filePath, String fileType) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final cacheFile = File('${await _cacheDir}/$cacheKey');

      if (await cacheFile.exists()) {
        return await cacheFile.readAsBytes();
      }
    } catch (e) {
      print('Cache read error: $e');
    }
    return null;
  }

  @override
  Future<Uint8List?> getPreview(String filePath) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final previewFile = File('${await _previewDir}/${cacheKey}_preview.png');

      if (await previewFile.exists()) {
        return await previewFile.readAsBytes();
      }
    } catch (e) {
      print('Preview read error: $e');
    }
    return null;
  }

  @override
  Future<void> clearCache() async {
    try {
      final cacheDirectory = Directory(await _cacheDir);
      final previewDirectory = Directory(await _previewDir);

      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
      if (await previewDirectory.exists()) {
        await previewDirectory.delete(recursive: true);
      }
    } catch (e) {
      print('Cache clear error: $e');
    }
  }
}
