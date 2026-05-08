import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';

// ===============================
// GEOFENCE SERVICE
// ===============================
// FR-3.2.9:  Support definition of geo-fenced zones
// FR-3.2.10: Detect entry into / exit from geo-fenced zones
// ===============================

class GeofenceZone {
  final String id;
  final String name;
  final String type; // 'safe' | 'restricted' | 'high-risk'
  final double centerLat;
  final double centerLng;
  final double radiusMeters;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.type,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
  });

  factory GeofenceZone.fromJson(Map<String, dynamic> json) {
    return GeofenceZone(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unnamed Zone',
      type: json['type'] ?? 'restricted',
      centerLat: (json['center']?['lat'] ?? 0).toDouble(),
      centerLng: (json['center']?['lng'] ?? 0).toDouble(),
      radiusMeters: (json['radius'] ?? 500).toDouble(),
    );
  }
}

class GeofenceService {
  static List<GeofenceZone>? _cached;

  /// Fetch all geofence zones from backend.
  /// Results are cached for the session to avoid redundant calls.
  Future<List<GeofenceZone>> fetchZones({bool forceRefresh = false}) async {
    if (_cached != null && !forceRefresh) return _cached!;

    try {
      final response = await BackendService.get('/geofences');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _cached = (data['geofences'] as List)
              .map((z) => GeofenceZone.fromJson(z))
              .toList();
          return _cached!;
        }
      }
    } catch (e) {
      debugPrint('GeofenceService: failed to fetch zones — $e');
    }

    return [];
  }

  /// Clears the cache so the next call re-fetches from backend.
  void invalidateCache() => _cached = null;
}
