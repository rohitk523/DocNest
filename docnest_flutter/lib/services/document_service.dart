import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../models/document.dart';

class DocumentService {
  String get baseUrl {
    final deviceIP = Platform.isAndroid ? "10.0.2.2" : "localhost";
    final physicalDeviceIP = "192.168.0.101";

    return Platform.isAndroid &&
            !Platform.environment.containsKey('FLUTTER_TEST')
        ? "http://$physicalDeviceIP:8000/api/v1/documents/"
        : "http://$deviceIP:8000/api/v1/documents/";
  }

  final String token;

  DocumentService({required this.token});

  // Helper method to determine content type
  MediaType _getMediaType(File file) {
    final extension = path.extension(file.path).toLowerCase();
    switch (extension) {
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.doc':
      case '.docx':
        return MediaType('application', 'msword');
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<List<Document>> getDocuments() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((doc) => Document.fromJson(doc as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = _parseErrorMessage(response);
        throw Exception('Failed to load documents: $errorMessage');
      }
    } on SocketException {
      throw Exception('Network error: Please check your internet connection');
    } catch (e) {
      throw Exception('Error connecting to server: $e');
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
      var uri = Uri.parse(baseUrl);
      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add form fields
      request.fields.addAll({
        'name': name,
        'description': description,
        'category': category,
      });

      // Prepare file
      final fileName = path.basename(file.path);
      final mediaType = _getMediaType(file);

      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: mediaType,
          filename: fileName,
        ),
      );

      // Send request
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Upload timed out. Please try again.');
        },
      );

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return Document.fromJson(json.decode(response.body));
        } catch (e) {
          throw Exception('Failed to parse server response: $e');
        }
      } else {
        final errorMessage = _parseErrorMessage(response);
        throw Exception('Upload failed: $errorMessage');
      }
    } on SocketException {
      throw Exception('Network error: Please check your internet connection');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error uploading document: $e');
    }
  }

  String _parseErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      return body['detail'] ?? 'Unknown error occurred';
    } catch (e) {
      return 'Status code: ${response.statusCode}';
    }
  }
}
