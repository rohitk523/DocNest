import 'package:docnest_flutter/providers/document_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf_render/pdf_render.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../models/document.dart';
import '../config/api_config.dart';
import '../utils/formatters.dart';
import 'dart:typed_data';
import '../services/documents/cache_service.dart';

class DocumentPreview extends StatefulWidget {
  final String fileType;
  final String filePath;
  final String token;
  final String category;
  final Document document; // Add this

  const DocumentPreview({
    Key? key,
    required this.fileType,
    required this.filePath,
    required this.token,
    required this.category,
    required this.document, // Add this
  }) : super(key: key);

  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  late Future<Widget> _previewWidget;
  final CacheService _cacheService = CacheService();

  @override
  void initState() {
    super.initState();
    _previewWidget = _loadPreview();
  }

  Future<Widget> _loadPreview() async {
    try {
      if (widget.filePath.isEmpty) {
        return _buildCategoryIcon();
      }

      try {
        // Check cache first
        if (await _cacheService.hasValidCache(
            widget.filePath, widget.fileType)) {
          final cachedBytes = await _cacheService.getFromCache(
              widget.filePath, widget.fileType);
          if (cachedBytes != null) {
            print('Using cached preview for: ${widget.filePath}');
            if (widget.fileType.startsWith('image/')) {
              return _buildImagePreview(cachedBytes);
            } else if (widget.fileType == 'application/pdf') {
              return await _buildPdfPreview(cachedBytes);
            }
          }
        }

        // Use the document ID directly for download
        final downloadUrl = Uri.parse(
            '${ApiConfig.baseUrl}/documents/${widget.document.id}/download');

        print('Document ID: ${widget.document.id}');
        print('Download URL: $downloadUrl');

        final response = await _retryableRequest(
          downloadUrl,
          ApiConfig.authHeaders(widget.token),
          maxAttempts: 2,
        );
        print(response.statusCode);

        if (response.statusCode != 200) {
          print('Error loading preview: ${response.statusCode}');
          print('Response body: ${response.body}');
          return _buildCategoryIcon();
        }

        final bytes = Uint8List.fromList(response.bodyBytes);
        await _cacheService.saveToCache(
            widget.filePath, widget.fileType, bytes);

        if (widget.fileType.startsWith('image/')) {
          return _buildImagePreview(bytes);
        } else if (widget.fileType == 'application/pdf') {
          return await _buildPdfPreview(bytes);
        } else if (widget.fileType == 'application/msword' ||
            widget.fileType ==
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
          return _buildDocumentIcon('DOC');
        }

        return _buildCategoryIcon();
      } catch (e) {
        print('Network error loading preview: $e');
        return _buildCategoryIcon();
      }
    } catch (e) {
      print('Error in _loadPreview: $e');
      return _buildCategoryIcon();
    }
  }

  Widget _buildImagePreview(List<int> bytes) {
    // Convert List<int> to Uint8List for image preview too
    final Uint8List uint8Bytes = Uint8List.fromList(bytes);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: MemoryImage(uint8Bytes),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<Widget> _buildPdfPreview(List<int> bytes) async {
    try {
      // Convert List<int> to Uint8List
      final Uint8List uint8Bytes = Uint8List.fromList(bytes);

      final document = await PdfDocument.openData(uint8Bytes);
      final firstPage = await document.getPage(1);
      final renderResult = await firstPage.render(
        width: 96,
        height: 96,
      );

      final image = await renderResult.createImageDetached();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final imageBytes = byteData!.buffer.asUint8List();

      await document.dispose();

      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: MemoryImage(imageBytes),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      print('Error rendering PDF preview: $e');
      return _buildDocumentIcon('PDF');
    }
  }

  Widget _buildCategoryIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: getCategoryColor(widget.category).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        getCategoryIcon(widget.category),
        color: getCategoryColor(widget.category),
        size: 24,
      ),
    );
  }

  Widget _buildDocumentIcon(String type) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.description,
            size: 20,
            color: Colors.grey,
          ),
          Text(
            type,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<http.Response> _retryableRequest(Uri uri, Map<String, String> headers,
      {int maxAttempts = 3}) async {
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        return await http
            .get(
          uri,
          headers: headers,
        )
            .timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );
      } catch (e) {
        attempts++;
        if (attempts == maxAttempts) rethrow;

        // Exponential backoff
        final waitTime = Duration(milliseconds: 1000 * attempts);
        print('Retry attempt $attempts after ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
    throw Exception('Failed after $maxAttempts attempts');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _previewWidget,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          print('Preview error: ${snapshot.error}');
          return _buildCategoryIcon();
        }

        return snapshot.data ?? _buildCategoryIcon();
      },
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
