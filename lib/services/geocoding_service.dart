import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeocodingService {
  /// Resolves a location name or address into LatLng using a multi-step approach:
  /// 1. Native Geocoding (Fastest, system-integrated)
  /// 2. OSM Nominatim API (Fallback for buildings, POIs, and cross-platform consistency)
  Future<LatLng?> resolveLocation(String query) async {
    if (query.trim().isEmpty) return null;

    // --- STEP 1: NATIVE GEOCODING ---
    try {
      List<Location> nativeResults = await locationFromAddress(query);
      if (nativeResults.isNotEmpty) {
        debugPrint('Geocoding: Found via Native');
        return LatLng(nativeResults.first.latitude, nativeResults.first.longitude);
      }
    } catch (e) {
      debugPrint('Native geocoding failed for "$query": $e');
    }

    // --- STEP 2: OSM NOMINATIM FALLBACK (BETTER FOR BUILDINGS/POIs) ---
    try {
      debugPrint('Geocoding: Attempting OSM Fallback for "$query"');
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1'
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'AtlasWatch/1.0', // Required by Nominatim policy
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          debugPrint('Geocoding: Found via OSM ($lat, $lon)');
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint('OSM geocoding error for "$query": $e');
    }

    return null;
  }
}
