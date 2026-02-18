import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';

  /// Save mandatory document details
  Future<void> saveProfile({
    required String passport,
    required String documentType,
    required String nationality,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'passport': passport,
      'documentType': documentType,
      'nationality': nationality,
    };

    await prefs.setString(_profileKey, jsonEncode(data));
  }

  /// Load saved profile (if exists)
  Future<Map<String, String>?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);

    if (raw == null) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    return {
      'passport': decoded['passport'] ?? '',
      'documentType': decoded['documentType'] ?? '',
      'nationality': decoded['nationality'] ?? '',
    };
  }

  /// Check if user has completed document setup
  Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_profileKey);
  }
}
