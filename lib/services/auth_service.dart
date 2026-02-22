import 'dart:convert';
import 'backend_service.dart';

class AuthService {
  Future<String?> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await BackendService.post(
        '/register',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? data['message'] ?? 'Registration failed';
      }
    } catch (e) {
      return 'Failed to connect to backend: $e';
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await BackendService.post(
        '/login',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? data['message'] ?? 'Login failed';
      }
    } catch (e) {
      return 'Failed to connect to backend: $e';
    }
  }
}
