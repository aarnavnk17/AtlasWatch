import '../models/risk_level.dart';

class RiskService {
  RiskLevel calculateRisk(int score) {
    if (score <= 4000) {
      return RiskLevel.low;
    } else if (score <= 8000) {
      return RiskLevel.medium;
    } else {
      return RiskLevel.high;
    }
  }
}
