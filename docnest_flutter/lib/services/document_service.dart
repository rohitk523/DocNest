// lib/services/document_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/document.dart';
import 'api_config.dart';

class DocumentService {
  final String token;

  DocumentService({required this.token});

  Future<List<Document>> getDocuments() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.documentsUrl),
        headers: ApiConfig.authHeaders(token),
      );

      print('GetDocuments Response Status: ${response.statusCode}');
      print('GetDocuments Response Body: ${response.body}');

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((doc) => Document.fromJson(doc as Map<String, dynamic>))
            .toList();
      } else {
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Failed to load documents';
        } catch (_) {
          errorMessage =
              'Failed to load documents. Status: ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in getDocuments: $e');
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Error loading documents: $e');
    }
  }

  Future<Document> uploadDocument({
    required String name,
    required String description,
    required String category,
    required File file,
  }) async {
    try {
      // Validate file size
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB limit
        throw Exception('File size exceeds 10MB limit');
      }

      // Create multipart request
      final uri = Uri.parse(ApiConfig.documentsUrl);
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll(ApiConfig.authHeaders(token));

      // Add form fields
      request.fields['name'] = name.trim();
      request.fields['description'] = description.trim();
      request.fields['category'] = category.toLowerCase();

      // Add file
      final fileName = path.basename(file.path);
      final fileExtension = path.extension(fileName).toLowerCase();
      final mimeType = _getContentType(fileExtension);

      final stream = http.ByteStream(file.openRead());
      final length = await file.length();

      final multipartFile = http.MultipartFile(
        'file',
        stream,
        length,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      // Send request and get response
      print('Sending upload request to: ${request.url}');
      final streamedResponse = await request.send();
      print('Upload response status: ${streamedResponse.statusCode}');

      // Get response body
      final response = await http.Response.fromStream(streamedResponse);
      print('Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.isEmpty) {
          throw Exception('Server returned empty response');
        }
        try {
          return Document.fromJson(json.decode(response.body));
        } catch (e) {
          print('Error parsing upload response: $e');
          throw Exception('Failed to parse server response');
        }
      } else {
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Upload failed';
        } catch (_) {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : 'Upload failed with status ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in uploadDocument: $e');
      throw Exception('Error uploading document: $e');
    }
  }

  Future<Document> updateDocument({
    required String documentId,
    String? name,
    String? description,
    String? category,
    File? file,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('${ApiConfig.documentsUrl}/$documentId'),
      );

      // Add headers
      request.headers.addAll(ApiConfig.authHeaders(token));

      // Add non-null fields
      if (name != null) request.fields['name'] = name.trim();
      if (description != null)
        request.fields['description'] = description.trim();
      if (category != null) request.fields['category'] = category.toLowerCase();

      // Add file if provided
      if (file != null) {
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('File size exceeds 10MB limit');
        }

        final fileName = path.basename(file.path);
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();

        final multipartFile = http.MultipartFile(
          'file',
          stream,
          length,
          filename: fileName,
          contentType:
              MediaType.parse(_getContentType(path.extension(fileName))),
        );

        request.files.add(multipartFile);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Update response status: ${response.statusCode}');
      print('Update response body: ${response.body}');

      if (response.statusCode == 200) {
        return Document.fromJson(json.decode(response.body));
      } else {
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Update failed';
        } catch (_) {
          errorMessage = 'Update failed with status ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in updateDocument: $e');
      throw Exception('Error updating document: $e');
    }
  }

  Future<void> deleteDocument(String documentId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.documentsUrl}/$documentId'),
        headers: ApiConfig.authHeaders(token),
      );

      print('Delete response status: ${response.statusCode}');
      print('Delete response body: ${response.body}');

      if (response.statusCode != 204) {
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Delete failed';
        } catch (_) {
          errorMessage = 'Delete failed with status ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in deleteDocument: $e');
      throw Exception('Error deleting document: $e');
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<Document> getDocumentById(String documentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.documentsUrl}/$documentId'),
        headers: ApiConfig.authHeaders(token),
      );

      print('GetDocumentById Response Status: ${response.statusCode}');
      print('GetDocumentById Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return Document.fromJson(json.decode(response.body));
      } else {
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Failed to load document';
        } catch (_) {
          errorMessage =
              'Failed to load document. Status: ${response.statusCode}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error in getDocumentById: $e');
      throw Exception('Error loading document: $e');
    }
  }
}
