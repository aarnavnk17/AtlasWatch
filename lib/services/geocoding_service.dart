import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'backend_service.dart';

class GeocodingService {
  Future<LatLng?> resolveLocation(String query) async {
    if (query.trim().isEmpty) return null;

    // --- STEP 1: NATIVE GEOCODING ---
    try {
      List<Location> nativeResults = await locationFromAddress(query).timeout(const Duration(seconds: 3));
      if (nativeResults.isNotEmpty) {
        debugPrint('✓ Geocoding: Found via Native');
        return LatLng(nativeResults.first.latitude, nativeResults.first.longitude);
      }
    } catch (e) {
      debugPrint('✗ Native geocoding failed: $e');
    }

    // --- STEP 2: BACKEND PROXY (HIGH RELIABILITY) ---
    // This bypasses Emulator DNS issues by asking the backend (Mac) to do the lookup
    try {
      debugPrint('🔍 Geocoding: Attempting Backend Proxy for "$query"');
      final encodedQuery = Uri.encodeComponent(query);
      final response = await BackendService.get('/geocode?q=$encodedQuery');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          debugPrint('✓ Geocoding: Found via Proxy ($lat, $lon)');
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint('✗ Backend Geocode Proxy failed: $e');
    }

    // --- STEP 3: DIRECT OSM FALLBACK ---
    try {
      debugPrint('🔍 Geocoding: Attempting Direct OSM (Nominatim) for "$query"');
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'AtlasWatchApp/1.0'}).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (_) {}

    return null;
  }
}
