/// Result returned by the AnomalyService after rule-based analysis.
class AnomalyResult {
  /// True if any anomaly rule was triggered.
  final bool anomalyDetected;

  /// Human-readable description of the triggered rule, or null.
  final String? reason;

  /// Tag identifying which rule fired: 'inactivity' | 'speed' | 'loitering' | 'night_highrisk' | null
  final String? ruleTag;

  const AnomalyResult({
    required this.anomalyDetected,
    this.reason,
    this.ruleTag,
  });

  static const AnomalyResult none = AnomalyResult(anomalyDetected: false);
}
