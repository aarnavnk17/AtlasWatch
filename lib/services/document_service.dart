import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'session_service.dart';
import 'backend_service.dart';
import 'dart:io';

class DocumentService {
  final SessionService _session = SessionService();

  Future<List<dynamic>> getDocuments() async {
    final email = await _session.getEmail();
    if (email == null) return [];

    try {
      final response = await BackendService.get('/documents?email=$email');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['documents'] ?? [];
      }
    } catch (e) {
      print('Error fetching documents: $e');
    }
    return [];
  }

  Future<bool> uploadDocument(File file, String category) async {
    final email = await _session.getEmail();
    if (email == null) return false;

    try {
      final baseUrl = await BackendService.getBaseUrl();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/documents/upload'),
      );

      request.fields['email'] = email;
      request.fields['category'] = category;

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('application', 'octet-stream'),
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading document: $e');
      return false;
    }
  }

  Future<bool> deleteDocument(String id) async {
    try {
      final response = await BackendService.delete('/documents/$id');
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }
}
