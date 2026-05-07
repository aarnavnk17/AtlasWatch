import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'backend_service.dart';

enum ZoneType { safe, restricted, highRisk }

class GeofenceZone {
  final String id;
  final String name;
  final ZoneType type;
  final LatLng center;
  final double radiusMeters;

  const GeofenceZone({
    required this.id,
    required this.name,
    required this.type,
    required this.center,
    required this.radiusMeters,
  });

  factory GeofenceZone.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? '').toLowerCase();
    ZoneType zoneType;
    switch (typeStr) {
      case 'safe':
        zoneType = ZoneType.safe;
        break;
      case 'high-risk':
      case 'high_risk':
        zoneType = ZoneType.highRisk;
        break;
      default:
        zoneType = ZoneType.restricted;
    }
    return GeofenceZone(
      id: json['id'] as String,
      name: json['name'] as String,
      type: zoneType,
      center: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      radiusMeters: (json['radius'] as num).toDouble(),
    );
  }
}

class GeofenceService {
  List<GeofenceZone>? _cachedZones;

  /// Fetch geofence zones from backend, with in-memory caching.
  Future<List<GeofenceZone>> fetchZones({bool forceRefresh = false}) async {
    if (_cachedZones != null && !forceRefresh) return _cachedZones!;

    try {
      final response = await BackendService.get('/geofences');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> zoneList = data['zones'] as List<dynamic>;
        _cachedZones = zoneList
            .map((z) => GeofenceZone.fromJson(z as Map<String, dynamic>))
            .toList();
        return _cachedZones!;
      }
    } catch (e) {
      debugPrint('GeofenceService: failed to fetch zones: $e');
    }

    // Fallback to empty list so the rest of the app still works
    _cachedZones = [];
    return _cachedZones!;
  }

  /// Returns the first zone that contains [point], or null if none.
  GeofenceZone? checkZone(LatLng point, List<GeofenceZone> zones) {
    for (final zone in zones) {
      if (_distanceMeters(point, zone.center) <= zone.radiusMeters) {
        return zone;
      }
    }
    return null;
  }

  /// Haversine distance between two LatLng points in metres.
  double _distanceMeters(LatLng a, LatLng b) {
    const r = 6371000.0; // Earth radius in metres
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;

    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(x), sqrt(1 - x));
    return r * c;
  }
}
