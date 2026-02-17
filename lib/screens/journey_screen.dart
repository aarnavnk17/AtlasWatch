import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/risk_level.dart';
import '../data/city_coordinates.dart';

class JourneyScreen extends StatefulWidget {
  final RiskLevel riskLevel;
  final String startLocation;
  final String endLocation;
  final String mode;
  final String reference;

  const JourneyScreen({
    super.key,
    required this.riskLevel,
    required this.startLocation,
    required this.endLocation,
    required this.mode,
    required this.reference,
  });

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _loadingRoute = true;
  String? _errorMessage;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      LatLng? start;
      LatLng? end;

      // 1. Try Local Lookup First (Comprehensive Offline Database)
      start = CityCoordinates.get(widget.startLocation);
      end = CityCoordinates.get(widget.endLocation);

      // 2. Fallback to API Geocoding
      if (start == null) {
        try {
          List<Location> locations = await locationFromAddress(widget.startLocation);
          if (locations.isNotEmpty) {
            start = LatLng(locations.first.latitude, locations.first.longitude);
          }
        } catch (e) {
            debugPrint("Geocoding failed for start: $e");
        }
      }

      if (end == null) {
         try {
          List<Location> locations = await locationFromAddress(widget.endLocation);
          if (locations.isNotEmpty) {
            end = LatLng(locations.first.latitude, locations.first.longitude);
          }
         } catch (e) {
             debugPrint("Geocoding failed for end: $e");
         }
      }

      if (start != null && end != null) {
        // 3. Fetch Actual Route from OSRM
        List<LatLng> routePoints = [start, end]; // Default straight line
        
        try {
            // OSRM Public Server (Driving)
            final url = Uri.parse(
                'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson'
            );
            
            final response = await http.get(url);
            
            if (response.statusCode == 200) {
                final data = json.decode(response.body);
                if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
                    final geometry = data['routes'][0]['geometry'];
                    final coordinates = geometry['coordinates'] as List;
                    
                    // Convert [lon, lat] points to LatLng
                    routePoints = coordinates.map((coord) {
                        return LatLng(coord[1], coord[0]);
                    }).toList();
                }
            } else {
                debugPrint('OSRM Error: ${response.statusCode}');
            }
        } catch (e) {
            debugPrint('Error fetching OSRM route: $e');
            // If API fails, we keep the straight line as fallback
        }

        if (!mounted) return;

        setState(() {
          _startLatLng = start;
          _endLatLng = end;
          _routePoints = routePoints; 
          _loadingRoute = false;
        });

        // Try to fit camera if map is already ready
        if (_isMapReady) {
           _fitRoute();
        }
      } else {
        setState(() {
             _loadingRoute = false;
             _errorMessage = "Could not find coordinates for '${widget.startLocation}' or '${widget.endLocation}'. Try a major city like 'Mumbai' or 'Pune'.";
        });
      }
    } catch (e) {
      debugPrint('Error overall fetch: $e');
      if (mounted) {
          setState(() {
              _loadingRoute = false;
              _errorMessage = "Error loading map: $e";
          });
      }
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    
    // Calculate bounds manually to be safe or use CameraFit
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: _routePoints, 
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      debugPrint("Error fitting camera: $e");
    }
  }

  Color get _riskColor {
    switch (widget.riskLevel) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }

  String get _riskLabel {
    switch (widget.riskLevel) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey in Progress')),
      body: Column(
        children: [
          // 🗺️ Map Section (Top Half)
          Expanded(
            flex: 5,
            child: _loadingRoute
                ? const Center(child: CircularProgressIndicator())
                : _startLatLng == null || _endLatLng == null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            _errorMessage ?? 'Could not load map route',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                        ),
                      ))
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _startLatLng!,
                          initialZoom: 10,
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _isMapReady = true;
                            _fitRoute();
                          },
                        ),
                        children: [
                          TileLayer(
                            // Carto Voyager is clean and nice for navigation
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.atlaswatch.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5.0,
                                color: Colors.blueAccent,
                                borderStrokeWidth: 2.0, // Add border to line for better visibility
                                borderColor: Colors.blue.shade900,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _startLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.circle, color: Colors.green, size: 20),
                              ),
                              Marker(
                                point: _endLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),

          // ℹ️ Details Section (Bottom Half)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Risk banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _riskColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: _riskColor),
                        const SizedBox(width: 12),
                        Text(
                          _riskLabel,
                          style: TextStyle(
                            color: _riskColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _info('From', widget.startLocation),
                  _info('To', widget.endLocation),
                  _info('Mode', widget.mode),
                  if (widget.reference.isNotEmpty) _info('Reference', widget.reference),

                  const Spacer(),

                  const Center(
                    child: Text(
                      'Journey is being monitored for safety',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
