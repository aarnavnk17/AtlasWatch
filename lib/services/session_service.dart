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
    try {
      final response = await BackendService.post(
        '/login',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': identifier, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final email = data['email'];
        if (email != null) {
          await saveEmail(email);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Login failed: $e');
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

    try {
      final response = await BackendService.get('/profile?email=$email');

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
    } catch (e) {
      debugPrint('isProfileComplete check failed: $e');
    }
    return false;
  }

  // ================================
  // LOAD PROFILE FROM BACKEND
  // ================================
  Future<Map<String, dynamic>?> loadProfile() async {
    final email = await getEmail();
    if (email == null) return null;

    try {
      final response = await BackendService.get('/profile?email=$email');

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);

      if (data['profile'] != null) {
        return data['profile'];
      }

      if (data['exists'] == true && data['profile'] != null) {
        return data['profile'];
      }
    } catch (e) {
      debugPrint('loadProfile failed: $e');
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

    try {
      final response = await BackendService.post(
        '/profile',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'passport': passport,
          'documentType': documentType,
          'nationality': nationality,
        }),
      );

      debugPrint("PROFILE STATUS: ${response.statusCode}");
      debugPrint("PROFILE RESPONSE: ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('saveProfile failed: $e');
      return false;
    }
  }

  // ================================
  // OPTIONAL LOCAL FLAG (UI COMPAT)
  // ================================
  Future<void> setProfileComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileCompleteKey, value);
  }
}
