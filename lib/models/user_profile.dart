// ===============================
// USER PROFILE MODEL (PERSISTENT)
// ===============================

import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  static String documentType = '';
  static String documentNumber = '';
  static String nationality = '';
  static String? photoPath;

  // Save profile to local storage
  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('documentType', documentType);
    await prefs.setString('documentNumber', documentNumber);
    await prefs.setString('nationality', nationality);
    if (photoPath != null) {
      await prefs.setString('photoPath', photoPath!);
    }
  }

  // Load profile from local storage
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    documentType = prefs.getString('documentType') ?? '';
    documentNumber = prefs.getString('documentNumber') ?? '';
    nationality = prefs.getString('nationality') ?? '';
    photoPath = prefs.getString('photoPath');
  }
}
