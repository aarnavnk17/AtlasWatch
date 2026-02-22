import 'dart:convert';
import 'backend_service.dart';
import 'session_service.dart';

class EmergencyContact {
  final String? id;
  final String name;
  final String phone;
  final String? relationship;

  EmergencyContact({
    this.id,
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
    );
  }
}

class ContactService {
  final SessionService _session = SessionService();

  Future<List<EmergencyContact>> getContacts() async {
    final email = await _session.getEmail();
    if (email == null) return [];

    try {
      final response = await BackendService.get('/contacts?email=$email');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['contacts'] ?? [];
        return list.map((json) => EmergencyContact.fromJson(json)).toList();
      }
    } catch (e) {
      // ignore and return empty
    }

    return [];
  }

  Future<bool> addContact(
    String name,
    String phone,
    String relationship,
  ) async {
    final email = await _session.getEmail();
    if (email == null) return false;

    try {
      final response = await BackendService.post(
        '/contacts',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': name,
          'phone': phone,
          'relationship': relationship,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteContact(String id) async {
    try {
      final response = await BackendService.delete('/contacts/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateContact(
    String id,
    String name,
    String phone,
    String relationship,
  ) async {
    try {
      final response = await BackendService.post(
        '/contacts/$id', // We'll implement PUT/POST on backend for updates
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'relationship': relationship,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
