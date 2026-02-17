import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';

  /// Save mandatory document details
  Future<void> saveProfile({
    required String passportId,
    required String documentType,
    required String nationality,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final data = {
      'passportId': passportId,
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
      'passportId': decoded['passportId'] ?? '',
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
