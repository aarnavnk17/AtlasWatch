import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/risk_level.dart';
import 'backend_service.dart';

// ===============================
// RISK SERVICE
// ===============================
// FR-3.2.13: Analyze movement using rule-based logic
// FR-3.2.14: Detect prolonged inactivity
// FR-3.2.15: Assign dynamic risk level
// FR-3.2.10/11: Detect and alert on geo-fence entry
// ===============================

class RiskAnalysisResult {
  final RiskLevel riskLevel;
  final bool anomalyFlag;
  final String reason;
  final Map<String, dynamic> details;

  const RiskAnalysisResult({
    required this.riskLevel,
    required this.anomalyFlag,
    required this.reason,
    required this.details,
  });

  factory RiskAnalysisResult.low() => const RiskAnalysisResult(
        riskLevel: RiskLevel.low,
        anomalyFlag: false,
        reason: 'Normal movement detected',
        details: {},
      );
}

class RiskService {
  // -------------------------------------------------------
  // analyzeLocation — calls backend /analyze endpoint.
  // Call this each time a location update is recorded.
  // Returns the full analysis including anomaly details.
  // -------------------------------------------------------
  Future<RiskAnalysisResult> analyzeLocation({
    required String email,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await BackendService.post(
        '/analyze',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'lat': lat, 'lng': lng}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return RiskAnalysisResult(
            riskLevel: _parseRiskLevel(data['risk_level']),
            anomalyFlag: data['anomaly_flag'] == true,
            reason: data['reason'] ?? 'No details',
            details: Map<String, dynamic>.from(data['details'] ?? {}),
          );
        }
      }
    } catch (e) {
      // Network unavailable — fall back gracefully
      debugPrint('RiskService: backend unreachable, using fallback — $e');
    }

    return RiskAnalysisResult.low();
  }

  // -------------------------------------------------------
  // calculateRisk — legacy score-based method, kept for
  // offline / demo fallback (used by CrimeService flow)
  // -------------------------------------------------------
  RiskLevel calculateRisk(int score) {
    if (score < 100) return RiskLevel.low;
    if (score < 200) return RiskLevel.medium;
    return RiskLevel.high;
  }

  RiskLevel _parseRiskLevel(String? raw) {
    switch (raw) {
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }
}
