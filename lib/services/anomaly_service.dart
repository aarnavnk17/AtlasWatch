import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/anomaly_result.dart';
import '../models/risk_level.dart';

/// Rule-based anomaly detection (SRS FR-3.2.13, FR-3.2.14, FR-3.2.15).
///
/// No external API needed. All rules operate on location history
/// maintained by the caller (JourneyScreen).
class AnomalyService {
  // ── Thresholds ────────────────────────────────────────────────────────────

  /// Minimum movement (metres) expected within [inactivityWindow] to avoid
  /// the inactivity rule triggering (FR-3.2.14).
  static const double _inactivityThresholdMeters = 30;

  /// How long (seconds) a user must stay within [_inactivityThresholdMeters]
  /// before it counts as "prolonged inactivity".
  static const int _inactivityWindowSeconds = 300; // 5 minutes

  /// Max plausible travel speed in km/h for ground transport.
  /// Exceeding this suggests a data anomaly or genuine emergency.
  static const double _maxSpeedKmh = 200;

  /// Radius (metres) within which repeated visits count as loitering.
  static const double _loiterRadiusMeters = 50;

  /// How many location samples within [_loiterRadiusMeters] count as loitering.
  static const int _loiterCountThreshold = 6;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Analyse [history] (newest-last list of timestamped points) against all
  /// rules. Returns the first triggered [AnomalyResult], or [AnomalyResult.none].
  AnomalyResult analyse({
    required List<_TimedPoint> history,
    required RiskLevel currentRiskLevel,
  }) {
    if (history.length < 2) return AnomalyResult.none;

    // Rule 1 – prolonged inactivity
    final inactivity = _checkInactivity(history);
    if (inactivity.anomalyDetected) return inactivity;

    // Rule 2 – unrealistic speed
    final speed = _checkSpeed(history);
    if (speed.anomalyDetected) return speed;

    // Rule 3 – loitering
    final loiter = _checkLoitering(history);
    if (loiter.anomalyDetected) return loiter;

    // Rule 4 – night movement in high-risk area
    final night = _checkNightHighRisk(history, currentRiskLevel);
    if (night.anomalyDetected) return night;

    return AnomalyResult.none;
  }

  // ── Private rules ─────────────────────────────────────────────────────────

  AnomalyResult _checkInactivity(List<_TimedPoint> history) {
    final now = history.last;
    final windowStart =
        now.time.subtract(Duration(seconds: _inactivityWindowSeconds));

    // Find all points in the window
    final inWindow =
        history.where((p) => !p.time.isBefore(windowStart)).toList();
    if (inWindow.length < 2) return AnomalyResult.none;

    final maxDist = _maxSpread(inWindow);
    if (maxDist < _inactivityThresholdMeters) {
      return const AnomalyResult(
        anomalyDetected: true,
        reason:
            'No significant movement detected for over 5 minutes. Are you okay?',
        ruleTag: 'inactivity',
      );
    }
    return AnomalyResult.none;
  }

  AnomalyResult _checkSpeed(List<_TimedPoint> history) {
    final last = history.last;
    final prev = history[history.length - 2];
    final dt = last.time.difference(prev.time).inSeconds;
    if (dt <= 0) return AnomalyResult.none;

    final dist = _meters(prev.point, last.point);
    final speedKmh = (dist / dt) * 3.6;

    if (speedKmh > _maxSpeedKmh) {
      return AnomalyResult(
        anomalyDetected: true,
        reason:
            'Unusual movement speed detected (${speedKmh.toStringAsFixed(0)} km/h). '
            'Please verify your safety.',
        ruleTag: 'speed',
      );
    }
    return AnomalyResult.none;
  }

  AnomalyResult _checkLoitering(List<_TimedPoint> history) {
    if (history.length < _loiterCountThreshold) return AnomalyResult.none;

    final recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    final anchor = recent.last.point;
    final nearCount = recent
        .where((p) => _meters(p.point, anchor) <= _loiterRadiusMeters)
        .length;

    if (nearCount >= _loiterCountThreshold) {
      return const AnomalyResult(
        anomalyDetected: true,
        reason:
            'You appear to have been in the same small area for an extended period. '
            'Flagging for safety check.',
        ruleTag: 'loitering',
      );
    }
    return AnomalyResult.none;
  }

  AnomalyResult _checkNightHighRisk(
      List<_TimedPoint> history, RiskLevel riskLevel) {
    if (riskLevel != RiskLevel.high) return AnomalyResult.none;

    final hour = DateTime.now().hour;
    final isNight = hour >= 22 || hour < 5;
    if (!isNight) return AnomalyResult.none;

    // Only flag if user has been moving (not just parked at night)
    if (history.length >= 2) {
      final last = history.last;
      final prev = history[history.length - 2];
      final dist = _meters(prev.point, last.point);
      if (dist > 10) {
        return const AnomalyResult(
          anomalyDetected: true,
          reason:
              'Movement detected in a high-risk area late at night. '
              'Exercise caution.',
          ruleTag: 'night_highrisk',
        );
      }
    }
    return AnomalyResult.none;
  }

  // ── Geometry helpers ──────────────────────────────────────────────────────

  double _meters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  double _maxSpread(List<_TimedPoint> points) {
    double max = 0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final d = _meters(points[i].point, points[j].point);
        if (d > max) max = d;
      }
    }
    return max;
  }
}

/// A location sample with its timestamp, used internally by AnomalyService.
class TimedPoint {
  final LatLng point;
  final DateTime time;
  const TimedPoint(this.point, this.time);
}

// Private alias so callers import only what they need
typedef _TimedPoint = TimedPoint;
