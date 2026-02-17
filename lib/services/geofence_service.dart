import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level callback for geofence events.
/// Must be persistent and not stripped by ProGuard (on Android).
@pragma('vm:entry-point')
void geofenceCallback(List<String> ids, GeofenceTransition transition) {
  debugPrint('Geofence Transition Occurred!');
  debugPrint('IDs: $ids');
  debugPrint('Transition: $transition');

  // Logic for what happens when entering/exiting
  for (var id in ids) {
    if (transition == GeofenceTransition.enter) {
      debugPrint('Entering geofence: $id');
      // Potential Action: Notify backend or send "I'm Safe"
    } else if (transition == GeofenceTransition.exit) {
      debugPrint('Exiting geofence: $id');
      // Potential Action: Trigger SOS countdown or alert contacts
    }
  }
}

class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  /// Initialize the geofencing system
  Future<void> initialize() async {
    try {
      await NativeGeofenceManager.instance.initialize();
      debugPrint("GeofenceManager Initialized");
    } catch (e) {
      debugPrint("Error initializing GeofenceManager: $e");
    }
  }

  static const String _kGeofenceKey = 'atlaswatch_geofences';

  /// Add a geofence region and persist it
  Future<void> addSafeZone({
    required String id,
    required double latitude,
    required double longitude,
    double radiusInMeters = 100,
  }) async {
    final Geofence region = Geofence(
      id: id,
      location: Location(latitude: latitude, longitude: longitude),
      radius: radiusInMeters,
      triggers: {GeofenceTransition.enter, GeofenceTransition.exit},
      iosSettings: const IOSGeofenceSettings(initialTrigger: true),
    );

    try {
      await NativeGeofenceManager.instance.registerGeofence(
        region,
        geofenceCallback,
      );
      
      // Persist the zone
      final prefs = await SharedPreferences.getInstance();
      final List<String> zones = prefs.getStringList(_kGeofenceKey) ?? [];
      
      final zoneData = jsonEncode({
        'id': id,
        'lat': latitude,
        'lng': longitude,
        'radius': radiusInMeters,
      });
      
      zones.add(zoneData);
      await prefs.setStringList(_kGeofenceKey, zones);

      debugPrint("Geofence registered and persisted: $id");
    } catch (e) {
      debugPrint("Error registering geofence $id: $e");
    }
  }

  /// Remove a geofence region and delete from persistence
  Future<void> removeZone(String id) async {
    try {
      await NativeGeofenceManager.instance.unregisterGeofence(id);
      
      final prefs = await SharedPreferences.getInstance();
      final List<String> zones = prefs.getStringList(_kGeofenceKey) ?? [];
      
      zones.removeWhere((z) {
        final data = jsonDecode(z);
        return data['id'] == id;
      });
      
      await prefs.setStringList(_kGeofenceKey, zones);
      
      debugPrint("Geofence unregistered and removed from storage: $id");
    } catch (e) {
      debugPrint("Error unregistering geofence $id: $e");
    }
  }

  /// List all registered geofences from persistence
  Future<List<Map<String, dynamic>>> getRegisteredGeofences() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> zones = prefs.getStringList(_kGeofenceKey) ?? [];
    return zones.map((z) => jsonDecode(z) as Map<String, dynamic>).toList();
  }
}
