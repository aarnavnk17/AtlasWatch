import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/risk_level.dart';
import '../data/city_coordinates.dart';
import '../services/journey_service.dart';

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
  final JourneyService _journeyService = JourneyService();
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
    
    // Start journey on backend
    _journeyService.startJourney(
      startLocation: widget.startLocation,
      endLocation: widget.endLocation,
      mode: widget.mode,
      reference: widget.reference,
      riskLevel: widget.riskLevel.toString().split('.').last, // e.g., 'high', 'low'
    );
  }

  @override
  void dispose() {
    // End journey when screen is popped/closed
    _journeyService.endJourney();
    super.dispose();
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
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Journey Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // --- MAP SECTION ---
          _loadingRoute
              ? Container(
                  color: const Color(0xFF121212),
                  child: const Center(child: CircularProgressIndicator(color: Colors.blue)),
                )
              : _startLatLng == null || _endLatLng == null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _errorMessage ?? 'Could not load map route',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    ))
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _startLatLng!,
                        initialZoom: 12,
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
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.atlaswatch.app',
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4.0,
                              color: Colors.blue.shade400,
                              borderColor: Colors.blue.shade900.withOpacity(0.5),
                              borderStrokeWidth: 2.0,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _startLatLng!,
                              width: 32,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.circle, color: Colors.blue, size: 14),
                              ),
                            ),
                            Marker(
                              point: _endLatLng!,
                              width: 50,
                              height: 50,
                              child: Icon(Icons.location_on_rounded, color: Colors.red.shade600, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),

          // --- OVERLAY INFO PANEL ---
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildInfoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & STATUS ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(),
              const Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 8),
                  SizedBox(width: 8),
                  Text('LIVE MONITORING', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- JOURNEY DATA ---
          _infoItem(Icons.my_location_rounded, 'ORIGIN', widget.startLocation),
          const Padding(
            padding: EdgeInsets.only(left: 10, top: 4, bottom: 4),
            child: Icon(Icons.more_vert, size: 16, color: Colors.blueGrey),
          ),
          _infoItem(Icons.location_on_outlined, 'DESTINATION', widget.endLocation),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _metaInfo('TRAVEL MODE', widget.mode, icon: Icons.directions_bus_filled_outlined)),
              if (widget.reference.isNotEmpty) 
                Expanded(child: _metaInfo('REFERENCE', widget.reference, icon: Icons.tag_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final bgColor = _riskColor.withOpacity(0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security_rounded, color: _riskColor, size: 14),
          const SizedBox(width: 8),
          Text(
            _riskLabel.toUpperCase(),
            style: TextStyle(color: _riskColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaInfo(String label, String value, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade400, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
