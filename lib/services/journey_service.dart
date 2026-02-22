import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';
import 'session_service.dart';

class JourneyService {
  final SessionService _session = SessionService();

  Future<bool> startJourney({
    required String startLocation,
    required String endLocation,
    required String mode,
    required String reference,
    required String riskLevel,
  }) async {
    final email = await _session.getEmail();
    if (email == null) return false;

    try {
      final response = await BackendService.post(
        '/journey',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'startLocation': startLocation,
          'endLocation': endLocation,
          'mode': mode,
          'reference': reference,
          'riskLevel': riskLevel,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to start journey: $e');
      return false;
    }
  }

  Future<bool> endJourney() async {
    final email = await _session.getEmail();
    if (email == null) return false;

    try {
      final response = await BackendService.delete(
        '/journey?email=$email',
        headers: {'Content-Type': 'application/json'},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Failed to end journey: $e');
      return false;
    }
  }
}
