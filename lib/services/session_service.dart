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
  /// Attempts login. Returns a map with keys:
  /// - 'status': 'otp' (OTP sent), 'ok' (no OTP), 'error'
  /// - 'email': email when available
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await BackendService.post(
        '/login',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': identifier, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final email = data['email'] as String?;
        if (email != null) {
          await saveEmail(email);
          if (data['otpSent'] == true) {
            return {'status': 'otp', 'email': email};
          }
          return {'status': 'ok', 'email': email};
        }
      } else if (response.statusCode == 401) {
        return {'status': 'error', 'message': 'Invalid credentials'};
      }
    } catch (e) {
      debugPrint('Login failed: $e');
    }

    return {'status': 'error', 'message': 'Login failed'};
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

  // ================================
  // OTP (One-time password)
  // ================================
  Future<bool> sendOtp(String email) async {
    try {
      final response = await BackendService.post(
        '/send-otp',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('sendOtp failed: $e');
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    try {
      final response = await BackendService.post(
        '/verify-otp',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('verifyOtp failed: $e');
      return false;
    }
  }
}
