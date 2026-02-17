import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_service.dart';
import 'session_service.dart';

class EmergencyContact {
  final int? id;
  final String name;
  final String phone;
  final String? relationship;

  EmergencyContact({this.id, required this.name, required this.phone, this.relationship});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
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

    final response = await http.get(
      Uri.parse('${BackendService.baseUrl}/contacts?email=$email'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['contacts'] ?? [];
      return list.map((json) => EmergencyContact.fromJson(json)).toList();
    }
    return [];
  }

  Future<bool> addContact(String name, String phone, String relationship) async {
    final email = await _session.getEmail();
    if (email == null) return false;

    final response = await http.post(
      Uri.parse('${BackendService.baseUrl}/contacts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'phone': phone,
        'relationship': relationship,
      }),
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteContact(int id) async {
    final response = await http.delete(
      Uri.parse('${BackendService.baseUrl}/contacts/$id'),
    );
    return response.statusCode == 200;
  }
}
