import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/risk_level.dart';
import '../models/anomaly_result.dart';
import '../data/city_coordinates.dart';
import '../services/journey_service.dart';
import '../services/geofence_service.dart';
import '../services/anomaly_service.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';

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
  // ── Map state ──────────────────────────────────────────────────────────────
  final MapController _mapController = MapController();
  final JourneyService _journeyService = JourneyService();
  List<LatLng> _routePoints = [];
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _loadingRoute = true;
  String? _errorMessage;
  bool _isMapReady = false;

  // ── Geofencing ─────────────────────────────────────────────────────────────
  final GeofenceService _geofenceService = GeofenceService();
  List<GeofenceZone> _geofenceZones = [];
  GeofenceZone? _currentZone;      // zone user is currently inside (null = none)
  GeofenceZone? _lastAlertedZone;  // avoid repeated alerts for same zone

  // ── Anomaly detection ──────────────────────────────────────────────────────
  final AnomalyService _anomalyService = AnomalyService();
  final List<TimedPoint> _locationHistory = [];
  static const int _maxHistorySize = 50;

  // ── Simulated position (for demo — walks from start toward end) ────────────
  LatLng? _simulatedPosition;
  int _simStep = 0;
  Timer? _trackingTimer;

  // ── Alert state ────────────────────────────────────────────────────────────
  bool _alertDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
    _loadGeofences();

    _journeyService.startJourney(
      startLocation: widget.startLocation,
      endLocation: widget.endLocation,
      mode: widget.mode,
      reference: widget.reference,
      riskLevel: widget.riskLevel.toString().split('.').last,
    );
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _journeyService.endJourney();
    super.dispose();
  }

  // ── Geofence loading ───────────────────────────────────────────────────────

  Future<void> _loadGeofences() async {
    final zones = await _geofenceService.fetchZones();
    if (mounted) {
      setState(() => _geofenceZones = zones);
    }
  }

  // ── Route fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    try {
      LatLng? start = CityCoordinates.get(widget.startLocation);
      LatLng? end = CityCoordinates.get(widget.endLocation);

      if (start == null) {
        try {
          final locs = await locationFromAddress(widget.startLocation);
          if (locs.isNotEmpty) {
            start = LatLng(locs.first.latitude, locs.first.longitude);
          }
        } catch (e) {
          debugPrint('Geocoding failed for start: $e');
        }
      }

      if (end == null) {
        try {
          final locs = await locationFromAddress(widget.endLocation);
          if (locs.isNotEmpty) {
            end = LatLng(locs.first.latitude, locs.first.longitude);
          }
        } catch (e) {
          debugPrint('Geocoding failed for end: $e');
        }
      }

      if (start != null && end != null) {
        List<LatLng> routePoints = [start, end];

        try {
          final url = Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}'
            '?overview=full&geometries=geojson',
          );
          final response = await http.get(url);
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['routes'] != null &&
                (data['routes'] as List).isNotEmpty) {
              final coords =
                  data['routes'][0]['geometry']['coordinates'] as List;
              routePoints =
                  coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
            }
          }
        } catch (e) {
          debugPrint('OSRM error: $e');
        }

        if (!mounted) return;

        setState(() {
          _startLatLng = start;
          _endLatLng = end;
          _routePoints = routePoints;
          _simulatedPosition = start;
          _loadingRoute = false;
        });

        if (_isMapReady) _fitRoute();

        // Begin periodic tracking once route is loaded
        _startTracking();
      } else {
        setState(() {
          _loadingRoute = false;
          _errorMessage =
              "Could not find coordinates for '${widget.startLocation}' "
              "or '${widget.endLocation}'. Try a major city like 'Mumbai'.";
        });
      }
    } catch (e) {
      debugPrint('Route fetch error: $e');
      if (mounted) {
        setState(() {
          _loadingRoute = false;
          _errorMessage = 'Error loading map: $e';
        });
      }
    }
  }

  // ── Tracking & analysis loop ───────────────────────────────────────────────

  void _startTracking() {
    // Tick every 15 seconds — advances simulated position and runs checks
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _trackingTick();
    });
    // Run immediately once
    _trackingTick();
  }

  Future<void> _trackingTick() async {
    if (!mounted) return;

    // 1. Advance simulated position along route
    final pos = _advanceSimulatedPosition();
    if (pos == null) return;

    setState(() => _simulatedPosition = pos);

    // 2. Record in history
    _locationHistory.add(TimedPoint(pos, DateTime.now()));
    if (_locationHistory.length > _maxHistorySize) {
      _locationHistory.removeAt(0);
    }

    // 3. Post location to backend
    _postLocation(pos);

    // 4. Geofence check
    if (_geofenceZones.isNotEmpty) {
      final zone = _geofenceService.checkZone(pos, _geofenceZones);
      if (zone != null && zone.id != _lastAlertedZone?.id) {
        _lastAlertedZone = zone;
        _currentZone = zone;
        if (zone.type != ZoneType.safe) {
          _showGeofenceAlert(zone);
        }
      } else if (zone == null) {
        _currentZone = null;
      }
      if (mounted) setState(() {});
    }

    // 5. Anomaly check
    if (_locationHistory.length >= 2) {
      final result = _anomalyService.analyse(
        history: _locationHistory,
        currentRiskLevel: widget.riskLevel,
      );
      if (result.anomalyDetected && !_alertDialogOpen) {
        _showAnomalyAlert(result);
      }
    }
  }

  /// Moves the simulated marker one step along _routePoints.
  LatLng? _advanceSimulatedPosition() {
    if (_routePoints.isEmpty) return _simulatedPosition;
    if (_simStep >= _routePoints.length - 1) return _routePoints.last;

    _simStep++;
    return _routePoints[_simStep];
  }

  Future<void> _postLocation(LatLng pos) async {
    try {
      final email = await SessionService().getEmail();
      if (email == null) return;
      await BackendService.post(
        '/location',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'lat': pos.latitude,
          'lng': pos.longitude,
          'riskLevel': widget.riskLevel.toString().split('.').last,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Location post failed: $e');
    }
  }

  // ── Alert dialogs ──────────────────────────────────────────────────────────

  void _showGeofenceAlert(GeofenceZone zone) {
    if (!mounted || _alertDialogOpen) return;
    _alertDialogOpen = true;

    final isHighRisk = zone.type == ZoneType.highRisk;
    final color = isHighRisk ? Colors.red : Colors.orange;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isHighRisk ? 'High-Risk Zone' : 'Restricted Zone',
                style: TextStyle(color: color),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have entered: ${zone.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isHighRisk
                  ? 'This is a high-risk zone. Monitoring authorities have been notified. '
                    'Stay alert and consider leaving the area immediately.'
                  : 'This is a restricted zone. Please proceed with caution and '
                    'follow local regulations.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _alertDialogOpen = false;
            },
            child: const Text('Understood'),
          ),
        ],
      ),
    ).then((_) => _alertDialogOpen = false);
  }

  void _showAnomalyAlert(AnomalyResult result) {
    if (!mounted || _alertDialogOpen) return;
    _alertDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber),
            SizedBox(width: 8),
            Text('Safety Check'),
          ],
        ),
        content: Text(result.reason ?? 'An anomaly was detected in your journey.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _alertDialogOpen = false;
            },
            child: const Text("I'm okay"),
          ),
        ],
      ),
    ).then((_) => _alertDialogOpen = false);
  }

  // ── Map helpers ────────────────────────────────────────────────────────────

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: _routePoints,
          padding: const EdgeInsets.all(50),
        ),
      );
    } catch (e) {
      debugPrint('Camera fit error: $e');
    }
  }

  Color _zoneColor(ZoneType type) {
    switch (type) {
      case ZoneType.safe:
        return Colors.green;
      case ZoneType.restricted:
        return Colors.orange;
      case ZoneType.highRisk:
        return Colors.red;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey in Progress')),
      body: Column(
        children: [
          // ── Map (top 55%) ──────────────────────────────────────────────────
          Expanded(
            flex: 55,
            child: _loadingRoute
                ? const Center(child: CircularProgressIndicator())
                : _startLatLng == null || _endLatLng == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _errorMessage ?? 'Could not load map route',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _startLatLng!,
                          initialZoom: 10,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.rotate,
                          ),
                          onMapReady: () {
                            _isMapReady = true;
                            _fitRoute();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.atlaswatch.app',
                          ),

                          // ── Geofence zone circles ──────────────────────────
                          if (_geofenceZones.isNotEmpty)
                            CircleLayer(
                              circles: _geofenceZones
                                  .map(
                                    (z) => CircleMarker(
                                      point: z.center,
                                      radius: z.radiusMeters,
                                      useRadiusInMeter: true,
                                      color: _zoneColor(z.type)
                                          .withValues(alpha: 0.18),
                                      borderColor:
                                          _zoneColor(z.type).withValues(alpha: 0.7),
                                      borderStrokeWidth: 2,
                                    ),
                                  )
                                  .toList(),
                            ),

                          // ── Route polyline ─────────────────────────────────
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5,
                                color: Colors.blueAccent,
                                borderStrokeWidth: 2,
                                borderColor: Colors.blue.shade900,
                              ),
                            ],
                          ),

                          // ── Markers ────────────────────────────────────────
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _startLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.circle,
                                    color: Colors.green, size: 20),
                              ),
                              Marker(
                                point: _endLatLng!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on,
                                    color: Colors.red, size: 40),
                              ),
                              if (_simulatedPosition != null)
                                Marker(
                                  point: _simulatedPosition!,
                                  width: 36,
                                  height: 36,
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                ),
                            ],
                          ),

                          // ── Zone labels ────────────────────────────────────
                          if (_geofenceZones.isNotEmpty)
                            MarkerLayer(
                              markers: _geofenceZones
                                  .map(
                                    (z) => Marker(
                                      point: z.center,
                                      width: 120,
                                      height: 24,
                                      child: Text(
                                        z.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _zoneColor(z.type),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
          ),

          // ── Details panel (bottom 45%) ─────────────────────────────────────
          Expanded(
            flex: 45,
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
                  // Risk / zone banner
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _riskLabel,
                                style: TextStyle(
                                  color: _riskColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_currentZone != null)
                                Text(
                                  'In zone: ${_currentZone!.name}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _zoneColor(_currentZone!.type),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _info('From', widget.startLocation),
                  _info('To', widget.endLocation),
                  _info('Mode', widget.mode),
                  if (widget.reference.isNotEmpty)
                    _info('Reference', widget.reference),

                  const Spacer(),

                  Center(
                    child: Text(
                      'Journey is being monitored for safety',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
