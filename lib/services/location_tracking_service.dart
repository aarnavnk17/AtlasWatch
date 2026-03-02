import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';
import 'session_service.dart';
import 'location_service.dart';
import 'crime_service.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _trackingTimer;
  final SessionService _session = SessionService();
  final LocationService _locationService = LocationService();
  final CrimeService _crimeService = CrimeService();

  void startTracking() {
    if (_trackingTimer != null) return;
    
    debugPrint('📍 Starting automatic location tracking...');
    // Initial update
    _performUpdate();
    
    // Schedule periodic updates every 5 minutes
    _trackingTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performUpdate();
    });
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    debugPrint('📍 Automatic location tracking stopped.');
  }

  Future<void> _performUpdate() async {
    try {
      final email = await _session.getEmail();
      if (email == null) return;

      final result = await _locationService.fetchCurrentLocation();
      if (result == null) return;

      // Fetch crime score using the CrimeService
      final score = await _crimeService.fetchCrimeScore(result.address ?? '');
      
      // Determine risk level based on score
      String riskLevelString = 'low';
      if (score >= 200) {
        riskLevelString = 'high';
      } else if (score >= 100) {
        riskLevelString = 'medium';
      }

      final response = await BackendService.post(
        '/location',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'lat': result.position.latitude,
          'lng': result.position.longitude,
          'address': result.address,
          'accuracy': result.position.accuracy,
          'riskLevel': riskLevelString,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('📍 Location auto-updated: ${result.position.latitude}, ${result.position.longitude} (Risk: $riskLevelString)');
      } else {
        debugPrint('📍 Location update failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📍 Location tracking error: $e');
    }
  }
}
