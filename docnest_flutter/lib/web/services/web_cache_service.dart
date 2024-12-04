// lib/services/cache/web_cache_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:pdf_render/pdf_render.dart';
import '../../services/documents/cache_service.dart';

class WebCacheService implements BaseCacheService {
  static final WebCacheService _instance = WebCacheService._internal();
  factory WebCacheService() => _instance;
  WebCacheService._internal();

  static const int PREVIEW_WIDTH = 200;
  static const int PREVIEW_HEIGHT = 280;
  static const Duration CACHE_DURATION = Duration(days: 7);

  final String _documentCacheKey = 'docnest_document_cache';
  final String _previewCacheKey = 'docnest_preview_cache';
  final html.Storage _localStorage = html.window.localStorage;

  Future<Map<String, dynamic>> _getCacheMetadata() async {
    final metadata = _localStorage['cache_metadata'];
    if (metadata != null) {
      return json.decode(metadata) as Map<String, dynamic>;
    }
    return {};
  }

  Future<void> _updateCacheMetadata(String key, DateTime timestamp) async {
    final metadata = await _getCacheMetadata();
    metadata[key] = timestamp.toIso8601String();
    _localStorage['cache_metadata'] = json.encode(metadata);
  }

  Future<bool> _isExpired(String key) async {
    final metadata = await _getCacheMetadata();
    if (!metadata.containsKey(key)) return true;

    final timestamp = DateTime.parse(metadata[key] as String);
    return DateTime.now().difference(timestamp) > CACHE_DURATION;
  }

  String _generateCacheKey(String filePath) {
    return md5.convert(utf8.encode(filePath)).toString();
  }

  @override
  Future<void> cacheDocumentWithName(String fileName, List<int> bytes) async {
    try {
      final base64Data = base64Encode(bytes);
      final key = '${_documentCacheKey}_$fileName';
      _localStorage[key] = base64Data;
      await _updateCacheMetadata(key, DateTime.now());
    } catch (e) {
      print('Error caching document: $e');
    }
  }

  @override
  Future<Uint8List?> getCachedDocumentByName(String fileName) async {
    try {
      final key = '${_documentCacheKey}_$fileName';
      if (await _isExpired(key)) return null;

      final base64Data = _localStorage[key];
      if (base64Data != null) {
        return Uint8List.fromList(base64Decode(base64Data));
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
      final documentKey = '${_documentCacheKey}_$cacheKey';
      final previewKey = '${_previewCacheKey}_$cacheKey';

      return !await _isExpired(documentKey) && !await _isExpired(previewKey);
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
      final key = '${_documentCacheKey}_$cacheKey';
      _localStorage[key] = base64Encode(bytes);
      await _updateCacheMetadata(key, DateTime.now());
    } catch (e) {
      print('Cache write error: $e');
    }
  }

  @override
  Future<void> savePreview(
      String filePath, String fileType, List<int> bytes) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final key = '${_previewCacheKey}_$cacheKey';

      Uint8List? previewBytes;
      final uint8Bytes = Uint8List.fromList(bytes);

      if (fileType.startsWith('application/pdf')) {
        previewBytes = await _generatePdfPreview(uint8Bytes);
      } else if (fileType.startsWith('image/')) {
        previewBytes = await _generateImagePreview(uint8Bytes);
      }

      if (previewBytes != null) {
        _localStorage[key] = base64Encode(previewBytes);
        await _updateCacheMetadata(key, DateTime.now());
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
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final completer = Completer<Uint8List?>();
      final img = html.ImageElement(src: url);

      img.onLoad.listen((_) async {
        final canvas = html.CanvasElement(
          width: PREVIEW_WIDTH,
          height: PREVIEW_HEIGHT,
        );
        final ctx = canvas.context2D;

        final scale = math.min(
          PREVIEW_WIDTH / img.width!,
          PREVIEW_HEIGHT / img.height!,
        );

        final scaledWidth = (img.width! * scale).round();
        final scaledHeight = (img.height! * scale).round();

        final x = ((PREVIEW_WIDTH - scaledWidth) / 2).round();
        final y = ((PREVIEW_HEIGHT - scaledHeight) / 2).round();

        ctx.drawImageScaledFromSource(
          img,
          0,
          0,
          img.width!,
          img.height!,
          x,
          y,
          scaledWidth,
          scaledHeight,
        );

        final dataUrl = canvas.toDataUrl('image/png');
        final base64 = dataUrl.split(',')[1];
        final imageBytes = base64Decode(base64);

        html.Url.revokeObjectUrl(url);
        completer.complete(Uint8List.fromList(imageBytes));
      });

      img.onError.listen((event) {
        html.Url.revokeObjectUrl(url);
        completer.complete(null);
      });

      return await completer.future;
    } catch (e) {
      print('Image preview generation error: $e');
      return null;
    }
  }

  @override
  Future<Uint8List?> getFromCache(String filePath, String fileType) async {
    try {
      final cacheKey = _generateCacheKey(filePath);
      final key = '${_documentCacheKey}_$cacheKey';

      if (await _isExpired(key)) return null;

      final base64Data = _localStorage[key];
      if (base64Data != null) {
        return Uint8List.fromList(base64Decode(base64Data));
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
      final key = '${_previewCacheKey}_$cacheKey';

      if (await _isExpired(key)) return null;

      final base64Data = _localStorage[key];
      if (base64Data != null) {
        return Uint8List.fromList(base64Decode(base64Data));
      }
    } catch (e) {
      print('Preview read error: $e');
    }
    return null;
  }

  @override
  Future<void> clearCache() async {
    try {
      // Get all cache keys
      final keys = _localStorage.keys.where((key) =>
          key.startsWith(_documentCacheKey) ||
          key.startsWith(_previewCacheKey));

      // Remove all cached items
      for (var key in keys) {
        _localStorage.remove(key);
      }

      // Clear metadata
      _localStorage.remove('cache_metadata');
    } catch (e) {
      print('Cache clear error: $e');
    }
  }

  // Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      for (var key in _localStorage.keys) {
        if (key.startsWith(_documentCacheKey) ||
            key.startsWith(_previewCacheKey)) {
          totalSize += _localStorage[key]!.length;
        }
      }
      return totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
      return 0;
    }
  }
}
