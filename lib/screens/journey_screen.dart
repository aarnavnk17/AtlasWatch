import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/risk_level.dart';
import '../data/city_coordinates.dart';
import '../services/journey_service.dart';
<<<<<<< Updated upstream
import '../services/geocoding_service.dart';
import '../widgets/sleek_animation.dart';
=======
import '../services/geofence_service.dart';
import '../services/tracking_service.dart';
import '../services/risk_service.dart';

// ===============================
// JOURNEY SCREEN
// ===============================
// FR-3.2.6:  Record location coordinates at predefined intervals
// FR-3.2.7:  Store location updates with timestamps
// FR-3.2.8:  Compute and display a safety status based on movement
// FR-3.2.10: Detect entry into geo-fenced zones
// FR-3.2.11: Generate alerts when user enters a high-risk zone
// FR-3.2.12: Notify monitoring authorities of geo-fence violations
// FR-3.2.13–15: AI anomaly detection + dynamic risk level display
// ===============================
>>>>>>> Stashed changes

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
  final GeofenceService _geofenceService = GeofenceService();
  final TrackingService _trackingService = TrackingService();

  List<LatLng> _routePoints = [];
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _loadingRoute = true;
  String? _errorMessage;
  final GeocodingService _geocoder = GeocodingService();
  bool _isMapReady = false;
  List<GeofenceZone> _geofenceZones = [];

  // Live AI risk state — updated by TrackingService callbacks (FR-3.2.8 / FR-3.2.15)
  late RiskLevel _liveRiskLevel;
  bool _anomalyDetected = false;
  String _anomalyReason = '';

  // Track alerted zone IDs to avoid repeated popups (FR-3.2.11)
  final Set<String> _alertedZones = {};

  @override
  void initState() {
    super.initState();
    _liveRiskLevel = widget.riskLevel;
    _fetchRoute();
    _loadGeofences();

    _journeyService.startJourney(
      startLocation: widget.startLocation,
      endLocation: widget.endLocation,
      mode: widget.mode,
      reference: widget.reference,
      riskLevel: widget.riskLevel.toString().split('.').last,
    );

    // Start live AI tracking (FR-3.2.6 / FR-3.2.13–15)
    _trackingService.startTracking(onUpdate: _onRiskUpdate);
  }

  @override
  void dispose() {
    _trackingService.stopTracking();
    _journeyService.endJourney();
    super.dispose();
  }

  // Called by TrackingService on each GPS + AI cycle
  void _onRiskUpdate(RiskAnalysisResult result) {
    if (!mounted) return;

    setState(() {
      _liveRiskLevel = result.riskLevel;
      _anomalyDetected = result.anomalyFlag;
      _anomalyReason = result.reason;
    });

    // Geofence entry alert (FR-3.2.11 / FR-3.2.12)
    if (result.anomalyFlag && result.details.containsKey('geofence')) {
      final geoInfo = result.details['geofence'] as Map<String, dynamic>;
      final zoneName = geoInfo['name'] ?? 'Unknown Zone';
      final zoneType = geoInfo['type'] ?? 'restricted';

      final matchedZone = _geofenceZones.firstWhere(
        (z) => z.name == zoneName,
        orElse: () => GeofenceZone(
          id: zoneName,
          name: zoneName,
          type: zoneType,
          centerLat: 0,
          centerLng: 0,
          radiusMeters: 0,
        ),
      );

      if (!_alertedZones.contains(matchedZone.id)) {
        _alertedZones.add(matchedZone.id);
        _showGeofenceAlert(zoneName, zoneType);
      }
    }

    // Non-geofence anomaly snackbar (speed spike / inactivity)
    if (result.anomalyFlag && !result.details.containsKey('geofence')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result.reason)),
              ],
            ),
            backgroundColor: _colorForRisk(result.riskLevel),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Alert dialog for geofence boundary crossing (FR-3.2.11)
  void _showGeofenceAlert(String zoneName, String zoneType) {
    final isHighRisk = zoneType == 'high-risk';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isHighRisk ? Icons.dangerous : Icons.warning_amber_rounded,
              color: isHighRisk ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Expanded(child: Text('Zone Alert')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have entered a ${zoneType.replaceAll('-', ' ').toUpperCase()} zone:'),
            const SizedBox(height: 8),
            Text(zoneName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (isHighRisk)
              const Text(
                '⚠️  Authorities have been notified. Please move to a safe area immediately.',
                style: TextStyle(color: Colors.red),
              )
            else
              const Text(
                'Please exercise caution in this area.',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadGeofences() async {
    final zones = await _geofenceService.fetchZones();
    if (mounted) setState(() => _geofenceZones = zones);
  }

  Future<void> _fetchRoute() async {
    try {
      LatLng? start = CityCoordinates.get(widget.startLocation);
      LatLng? end = CityCoordinates.get(widget.endLocation);

<<<<<<< Updated upstream
      // 1. Try Local Lookup First (Comprehensive Offline Database)
      start = CityCoordinates.get(widget.startLocation);
      end = CityCoordinates.get(widget.endLocation);

      // 2. Fallback to Robust Geocoding Service (Native + Web Fallback)
      if (start == null) {
        start = await _geocoder.resolveLocation(widget.startLocation);
      }

      if (end == null) {
        end = await _geocoder.resolveLocation(widget.endLocation);
=======
      if (start == null) {
        try {
          final locs = await locationFromAddress(widget.startLocation);
          if (locs.isNotEmpty) start = LatLng(locs.first.latitude, locs.first.longitude);
        } catch (e) { debugPrint('Geocoding start: $e'); }
      }

      if (end == null) {
        try {
          final locs = await locationFromAddress(widget.endLocation);
          if (locs.isNotEmpty) end = LatLng(locs.first.latitude, locs.first.longitude);
        } catch (e) { debugPrint('Geocoding end: $e'); }
>>>>>>> Stashed changes
      }

      if (start != null && end != null) {
        List<LatLng> routePoints = [start, end];

        try {
          final url = Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
          );
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
              final coords = data['routes'][0]['geometry']['coordinates'] as List;
              routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
            }
          }
        } catch (e) { debugPrint('OSRM error: $e'); }

        if (!mounted) return;
        setState(() {
          _startLatLng = start;
          _endLatLng = end;
          _routePoints = routePoints;
          _loadingRoute = false;
        });
        if (_isMapReady) _fitRoute();
      } else {
        setState(() {
          _loadingRoute = false;
          _errorMessage = "Could not find coordinates for '${widget.startLocation}' or '${widget.endLocation}'.";
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingRoute = false; _errorMessage = 'Error loading map: $e'; });
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(coordinates: _routePoints, padding: const EdgeInsets.all(50)),
      );
    } catch (e) { debugPrint('fitCamera: $e'); }
  }

  Color _geofenceColor(String type) {
    switch (type) {
      case 'high-risk':  return Colors.red;
      case 'restricted': return Colors.orange;
      case 'safe':       return Colors.green;
      default:           return Colors.blue;
    }
  }

  Color _colorForRisk(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:    return Colors.green;
      case RiskLevel.medium: return Colors.orange;
      case RiskLevel.high:   return Colors.red;
    }
  }

  Color get _riskColor => _colorForRisk(_liveRiskLevel);

  String get _riskLabel {
    switch (_liveRiskLevel) {
      case RiskLevel.low:    return 'Low Risk';
      case RiskLevel.medium: return 'Medium Risk';
      case RiskLevel.high:   return 'High Risk';
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
<<<<<<< Updated upstream
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
                        minZoom: 2,
                        maxZoom: 18,
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
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.atlaswatch.app',
                          retinaMode: RetinaMode.isHighDensity(context),
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

          // --- ZOOM CONTROLS ---
          if (!_loadingRoute && _startLatLng != null)
            Positioned(
              right: 20,
              top: 20,
              child: SleekAnimation(
                delay: const Duration(milliseconds: 300),
                type: SleekAnimationType.fade,
                child: Column(
                  children: [
                    _mapButton(Icons.add_rounded, () {
                      _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                    }),
                    const SizedBox(height: 8),
                    _mapButton(Icons.remove_rounded, () {
                      _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                    }),
                    const SizedBox(height: 8),
                    _mapButton(Icons.my_location_rounded, () => _fitRoute()),
                  ],
                ),
=======
          // Live AI Risk Banner (FR-3.2.8 / FR-3.2.15)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: _riskColor.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _anomalyDetected ? Icons.warning_amber_rounded : Icons.shield,
                  color: _riskColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Safety Status: $_riskLabel',
                        style: TextStyle(color: _riskColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (_anomalyDetected && _anomalyReason.isNotEmpty)
                        Text(
                          _anomalyReason,
                          style: TextStyle(color: _riskColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (_anomalyDetected)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _riskColor, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),

          // Map Section
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
                          onMapReady: () { _isMapReady = true; _fitRoute(); },
                        ),
                        children: [
                          TileLayer(
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
                                borderStrokeWidth: 2.0,
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
                          // Geofence Zone Overlays (FR-3.2.10/11)
                          if (_geofenceZones.isNotEmpty)
                            CircleLayer(
                              circles: _geofenceZones.map((zone) {
                                final color = _geofenceColor(zone.type);
                                return CircleMarker(
                                  point: LatLng(zone.centerLat, zone.centerLng),
                                  radius: zone.radiusMeters,
                                  useRadiusInMeter: true,
                                  color: color.withValues(alpha: 0.15),
                                  borderColor: color,
                                  borderStrokeWidth: 2.0,
                                );
                              }).toList(),
                            ),
                          if (_geofenceZones.isNotEmpty)
                            MarkerLayer(
                              markers: _geofenceZones.map((zone) => Marker(
                                point: LatLng(zone.centerLat, zone.centerLng),
                                width: 120,
                                height: 30,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _geofenceColor(zone.type).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    zone.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )).toList(),
                            ),
                        ],
                      ),
          ),

          // Details Section
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info('From', widget.startLocation),
                  _info('To', widget.endLocation),
                  _info('Mode', widget.mode),
                  if (widget.reference.isNotEmpty) _info('Reference', widget.reference),
                  const Spacer(),
                  if (_geofenceZones.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(Colors.green, 'Safe'),
                        const SizedBox(width: 12),
                        _legendDot(Colors.orange, 'Restricted'),
                        const SizedBox(width: 12),
                        _legendDot(Colors.red, 'High-Risk'),
                      ],
                    ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'AI monitoring active — location tracked every 2 min',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
>>>>>>> Stashed changes
              ),
            ),

          // --- OVERLAY INFO PANEL ---
          Align(
            alignment: Alignment.bottomCenter,
            child: SleekAnimation(
              delay: const Duration(milliseconds: 500),
              type: SleekAnimationType.slide,
              slideOffset: const Offset(0, 0.2),
              child: _buildInfoPanel(),
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< Updated upstream
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
=======
  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(value)),
>>>>>>> Stashed changes
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

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
