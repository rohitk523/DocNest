// lib/services/document_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../models/document.dart'; // Import the Document model

class DocumentService {
  String get baseUrl {
    final deviceIP = Platform.isAndroid ? "10.0.2.2" : "localhost";
    final physicalDeviceIP = "192.168.0.101"; // Replace X with your IP

    return Platform.isAndroid &&
            !Platform.environment.containsKey('FLUTTER_TEST')
        ? "http://$physicalDeviceIP:8000/api/v1/auth"
        : "http://$deviceIP:8000/api/v1/auth";
  }

  final String token;

  DocumentService({required this.token});

  Future<List<Document>> getDocuments() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data
            .map((doc) => Document.fromJson(doc as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load documents');
      }
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
      var request = http.MultipartRequest('POST', Uri.parse(baseUrl));

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['name'] = name;
      request.fields['description'] = description;
      request.fields['category'] = category;

      // Add file
      var fileStream = http.ByteStream(file.openRead());
      var length = await file.length();
      var multipartFile = http.MultipartFile(
        'file',
        fileStream,
        length,
        filename: file.path.split('/').last,
        contentType: MediaType('application', 'octet-stream'),
      );
      request.files.add(multipartFile);

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return Document.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      } else {
        throw Exception('Failed to upload document: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading document: $e');
    }
  }
}
