import '../models/risk_level.dart';

class RiskService {
  RiskLevel calculateRisk(int score) {
    if (score < 100) {
      return RiskLevel.low;
    } else if (score < 200) {
      return RiskLevel.medium;
    } else {
      return RiskLevel.high;
    }
  }
}
