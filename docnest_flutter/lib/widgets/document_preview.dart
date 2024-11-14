import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:ui' as ui;
import '../services/api_config.dart';
import '../utils/formatters.dart';

class DocumentPreview extends StatefulWidget {
  final String fileType;
  final String filePath;
  final String token;
  final String category;

  const DocumentPreview({
    Key? key,
    required this.fileType,
    required this.filePath,
    required this.token,
    required this.category,
  }) : super(key: key);

  @override
  State<DocumentPreview> createState() => _DocumentPreviewState();
}

class _DocumentPreviewState extends State<DocumentPreview> {
  late Future<Widget> _previewWidget;

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

      // Get download URL for the document
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}${widget.filePath}/download'),
        headers: ApiConfig.authHeaders(widget.token),
      );

      if (response.statusCode != 200) {
        print('Error loading preview: ${response.statusCode}');
        return _buildCategoryIcon();
      }

      // Handle different file types
      if (widget.fileType.startsWith('image/')) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(response.bodyBytes),
              fit: BoxFit.cover,
            ),
          ),
        );
      } else if (widget.fileType == 'application/pdf') {
        try {
          // Load PDF document
          final document = await PdfDocument.openData(response.bodyBytes);

          // Get first page
          final firstPage = await document.getPage(1);

          // Render the page
          final renderResult = await firstPage.render(
            width: 96, // 48 * 2 for better quality
            height: 96,
          );

          // Convert to image data
          final image = await renderResult.createImageDetached();

          // Convert to bytes
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData!.buffer.asUint8List();

          // Dispose of resources
          await document.dispose();

          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: MemoryImage(bytes),
                fit: BoxFit.cover,
              ),
            ),
          );
        } catch (e) {
          print('Error rendering PDF preview: $e');
          return _buildDocumentIcon('PDF');
        }
      } else if (widget.fileType == 'application/msword' ||
          widget.fileType ==
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
        return _buildDocumentIcon('DOC');
      }

      return _buildCategoryIcon();
    } catch (e) {
      print('Error loading preview: $e');
      return _buildCategoryIcon();
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
