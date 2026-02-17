import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class AuthService {
  static const String baseUrl = BackendService.baseUrl;

  Future<String?> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return null;
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? 'Registration failed';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return null;
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? 'Login failed';
    }
  }
}
