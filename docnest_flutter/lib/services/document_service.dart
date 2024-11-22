// lib/services/document_service.dart
import 'dart:async';
import 'dart:io';
import 'package:docnest_flutter/services/documents/cache_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/document.dart';
import '../config/api_config.dart';

class DocumentService {
  final String token;
  static const int maxRetries = 3;
  static const int timeoutSeconds = 30;

  DocumentService({required this.token});

  // Helper method to handle API responses
  T _handleResponse<T>(
      http.Response response, T Function(Map<String, dynamic>) fromJson) {
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        throw Exception('Server returned empty response');
      }
      try {
        return fromJson(json.decode(response.body));
      } catch (e) {
        print('Error parsing response: $e');
        throw Exception('Failed to parse server response');
      }
    } else {
      String errorMessage;
      try {
        final errorBody = json.decode(response.body);
        errorMessage = errorBody['detail'] ?? 'Operation failed';
      } catch (_) {
        errorMessage = 'Operation failed with status ${response.statusCode}';
      }
      throw Exception(errorMessage);
    }
  }

  Future<List<Document>> getDocuments() async {
    try {
      print('Fetching documents from: ${ApiConfig.documentsUrl}');
      final response = await http.get(
        Uri.parse(ApiConfig.documentsUrl),
        headers: ApiConfig.authHeaders(token),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((doc) => Document.fromJson(doc as Map<String, dynamic>))
            .toList();
      }

      return _handleResponse(response, (json) => []);
    } catch (e) {
      print('Error in getDocuments: $e');
      if (e.toString().contains('Connection refused')) {
        throw Exception(
            'Unable to connect to server. Please check your internet connection.');
      }
      throw Exception('Error loading documents: $e');
    }
  }

  // lib/services/document_service.dart

  Future<Document> uploadDocument({
    required String name,
    required String description,
    required String category,
    required File file,
  }) async {
    try {
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('File size exceeds 10MB limit');
      }

      final normalizedCategory = category.toLowerCase().trim();
      final fileName = path.basename(file.path);

      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConfig.documentsUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields.addAll({
        'name': name.trim(),
        'description': description.trim(),
        'category': normalizedCategory,
      });

      final fileBytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(_getContentType(path.extension(fileName))),
      );

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final document = Document.fromJson(json.decode(response.body));

        // Cache both the document and its preview
        final cacheService = CacheService();
        await Future.wait([
          cacheService.saveToCache(
              document.filePath!, document.fileType!, fileBytes),
          _cacheDocumentPreview(
              document.filePath!, fileBytes, document.fileType!),
        ]);

        return document;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['detail'] ??
            'Operation failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Error in uploadDocument: $e');
      rethrow;
    }
  }

  Future<void> _cacheDocumentPreview(
      String filePath, List<int> fileBytes, String fileType) async {
    try {
      final cacheService = CacheService();
      await cacheService.savePreview(filePath, fileType, fileBytes);
    } catch (e) {
      print('Error caching preview: $e');
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
      // Construct URL
      final url = Uri.parse('${ApiConfig.baseUrl}/documents/$documentId');
      print('Updating document at: $url');

      // Create multipart request
      final request = http.MultipartRequest('PUT', url);

      // Add proper authorization header - FIXED FORMAT
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Log token for debugging (remember to remove in production)
      print('Using token: $token');

      // Add fields if they have values
      if (name != null) request.fields['name'] = name.trim();
      if (description != null)
        request.fields['description'] = description.trim();
      if (category != null) request.fields['category'] = category.toLowerCase();

      // Log the request details
      print('Update request headers: ${request.headers}');
      print('Update request fields: ${request.fields}');

      // Add file if provided
      if (file != null) {
        final fileSize = await file.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('File size exceeds 10MB limit');
        }

        final fileName = path.basename(file.path);
        final bytes = await file.readAsBytes();

        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType:
              MediaType.parse(_getContentType(path.extension(fileName))),
        );

        request.files.add(multipartFile);
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

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
      rethrow;
    }
  }

  Future<void> deleteDocument(String documentId) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        attempts++;
        final url = Uri.parse('${ApiConfig.documentsUrl}$documentId');

        print('Deleting document at: $url (Attempt $attempts of $maxRetries)');

        final response = await http
            .delete(
          url,
          headers: ApiConfig.authHeaders(token),
        )
            .timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            throw TimeoutException('Request timed out');
          },
        );

        print('Delete response status: ${response.statusCode}');
        print('Delete response body: ${response.body}');

        if (response.statusCode == 204 || response.statusCode == 200) {
          return; // Success
        }

        // If we get a 404, no need to retry
        if (response.statusCode == 404) {
          throw Exception('Document not found');
        }

        // If we get a 401/403, no need to retry
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw Exception('Session Expired Please SignIn again');
        }

        // For other status codes, try to parse error message
        String errorMessage;
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['detail'] ?? 'Delete failed';
        } catch (_) {
          errorMessage = 'Delete failed with status ${response.statusCode}';
        }

        // On last attempt, throw the error
        if (attempts == maxRetries) {
          throw Exception(errorMessage);
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: attempts));
        continue;
      } on SocketException catch (e) {
        if (attempts == maxRetries) {
          throw Exception(
              'Network error: Please check your internet connection');
        }
        await Future.delayed(Duration(seconds: attempts));
        continue;
      } on TimeoutException catch (e) {
        if (attempts == maxRetries) {
          throw Exception('Request timed out. Please try again');
        }
        await Future.delayed(Duration(seconds: attempts));
        continue;
      } catch (e) {
        // For other errors, if they're not retryable, throw immediately
        if (e.toString().contains('Authentication failed') ||
            e.toString().contains('Document not found')) {
          throw Exception(e.toString());
        }

        if (attempts == maxRetries) {
          throw Exception('Error deleting document: $e');
        }
        await Future.delayed(Duration(seconds: attempts));
        continue;
      }
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
}
