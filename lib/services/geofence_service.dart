import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level callback for geofence events.
/// Must be persistent and not stripped by ProGuard (on Android).
@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  debugPrint('Geofence Event Occurred!');
  debugPrint('IDs: ${params.geofences.map((g) => g.id).toList()}');
  debugPrint('Event: ${params.event}');

  // Logic for what happens when entering/exiting
  for (var geofence in params.geofences) {
    final id = geofence.id;
    if (params.event == GeofenceEvent.enter) {
      debugPrint('Entering geofence: $id');
      // Potential Action: Notify backend or send "I'm Safe"
    } else if (params.event == GeofenceEvent.exit) {
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
      radiusMeters: radiusInMeters,
      triggers: {GeofenceEvent.enter, GeofenceEvent.exit},
      androidSettings: const AndroidGeofenceSettings(
        initialTriggers: {GeofenceEvent.enter},
      ),
      iosSettings: const IosGeofenceSettings(initialTrigger: true),
    );

    try {
      await NativeGeofenceManager.instance.createGeofence(
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
      await NativeGeofenceManager.instance.removeGeofenceById(id);
      
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
