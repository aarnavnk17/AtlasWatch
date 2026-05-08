import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/risk_level.dart';
import 'backend_service.dart';
import 'risk_service.dart';
import 'session_service.dart';

// ===============================
// TRACKING SERVICE
// ===============================
// Periodically records GPS location to the backend, then
// calls the AI /analyze endpoint to get a live risk level.
//
// FR-3.2.6: Record location coordinates at predefined intervals
// FR-3.2.7: Store location updates along with timestamps
// FR-3.2.8: Compute and display a safety status
// FR-3.2.13–15: Run anomaly detection on each update
// ===============================

typedef RiskUpdateCallback = void Function(RiskAnalysisResult result);

class TrackingService {
  static const Duration _interval = Duration(minutes: 2);

  final RiskService _riskService = RiskService();
  final SessionService _session = SessionService();

  Timer? _timer;
  RiskUpdateCallback? onRiskUpdate;

  bool get isTracking => _timer != null && _timer!.isActive;

  // Start periodic location tracking + AI analysis
  void startTracking({RiskUpdateCallback? onUpdate}) {
    onRiskUpdate = onUpdate;
    _timer?.cancel();

    // Run immediately, then every _interval
    _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
    debugPrint('TrackingService: started (interval=${_interval.inSeconds}s)');
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    debugPrint('TrackingService: stopped');
  }

  Future<void> _tick() async {
    final email = await _session.getEmail();
    if (email == null) return;

    try {
      // 1. Get current GPS position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));

      final lat = position.latitude;
      final lng = position.longitude;

      // 2. POST location to backend (FR-3.2.6/7)
      await BackendService.post(
        '/location',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'lat': lat,
          'lng': lng,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      // 3. Run AI anomaly analysis (FR-3.2.13–15)
      final analysis = await _riskService.analyzeLocation(
        email: email,
        lat: lat,
        lng: lng,
      );

      debugPrint(
        'TrackingService: [$lat, $lng] '
        'risk=${analysis.riskLevel.label} '
        'anomaly=${analysis.anomalyFlag} '
        'reason="${analysis.reason}"',
      );

      // 4. Notify UI via callback
      onRiskUpdate?.call(analysis);
    } catch (e) {
      debugPrint('TrackingService tick error: $e');
    }
  }

  // Manual one-shot analysis (e.g. on app resume)
  Future<RiskAnalysisResult?> analyzeNow() async {
    final email = await _session.getEmail();
    if (email == null) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));

      return await _riskService.analyzeLocation(
        email: email,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      debugPrint('TrackingService analyzeNow error: $e');
      return null;
    }
  }
}
