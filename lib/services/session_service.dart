import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class SessionService {
  static const _emailKey = 'user_email';
  static const _profileCompleteKey = 'profile_complete';

  // ================================
  // LOGIN
  // ================================
  Future<bool> login(String identifier, String password) async {
    final uri = Uri.parse('${BackendService.baseUrl}/login');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'identifier': identifier, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final email = data['email'];
      if (email != null) {
        await saveEmail(email);
        return true;
      }
    }

    return false;
  }

  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_emailKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_profileCompleteKey);
  }

  // ================================
  // PROFILE BACKEND CHECK (FIXED)
  // ================================
  Future<bool> isProfileComplete() async {
    final email = await getEmail();
    if (email == null) return false;

    final uri = Uri.parse('${BackendService.baseUrl}/profile?email=$email');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return false;
    }

    final data = json.decode(response.body);

    // FIX: check for profile object instead of "exists"
    if (data['profile'] != null) {
      return true;
    }

    if (data['exists'] == true) {
      return true;
    }

    return false;
  }

  // ================================
  // LOAD PROFILE FROM BACKEND
  // ================================
  Future<Map<String, dynamic>?> loadProfile() async {
    final email = await getEmail();
    if (email == null) return null;

    final uri = Uri.parse('${BackendService.baseUrl}/profile?email=$email');

    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);

    if (data['profile'] != null) {
      return data['profile'];
    }

    if (data['exists'] == true && data['profile'] != null) {
      return data['profile'];
    }

    return null;
  }

  // ================================
  // SAVE PROFILE TO BACKEND
  // ================================
  Future<bool> saveProfile({
    required String passport,
    required String documentType,
    required String nationality,
  }) async {
    final email = await getEmail();
    if (email == null) return false;

    final uri = Uri.parse('${BackendService.baseUrl}/profile');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'passport': passport,
        'documentType': documentType,
        'nationality': nationality,
      }),
    ).timeout(const Duration(seconds: 10));

    debugPrint("PROFILE STATUS: ${response.statusCode}");
    debugPrint("PROFILE RESPONSE: ${response.body}");

    return response.statusCode == 200;
  }

  // ================================
  // OPTIONAL LOCAL FLAG (UI COMPAT)
  // ================================
  Future<void> setProfileComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileCompleteKey, value);
  }
}
