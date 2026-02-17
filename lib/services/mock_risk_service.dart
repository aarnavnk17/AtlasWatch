// ===============================
// MOCK RISK SERVICE (GPS-BASED)
// ===============================
// Simulates safety risk using device location
// Frontend-only, backend-ready
// ===============================

import '../models/risk_level.dart';

class MockRiskService {
  // --------------------------------------------------
  // OLD METHOD (optional – keep if used elsewhere)
  // --------------------------------------------------
  Future<RiskLevel> getRiskLevel({required dynamic locationContext}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return RiskLevel.low;
  }

  // --------------------------------------------------
  // NEW METHOD – BASED ON GPS COORDINATES
  // --------------------------------------------------
  Future<RiskLevel> getRiskLevelFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    /*
      Mock logic (simple + explainable):

      - Higher latitude → unfamiliar / foreign region
      - Certain longitude ranges → medium risk
      - Otherwise → low risk

      This logic is ONLY for UI demo.
      Can be replaced by backend later.
    */

    // Example logic
    if (latitude.abs() > 45) {
      return RiskLevel.medium;
    }

    if (longitude.abs() > 90) {
      return RiskLevel.medium;
    }

    return RiskLevel.low;
  }
}
