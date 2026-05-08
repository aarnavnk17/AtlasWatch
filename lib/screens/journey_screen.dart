// ===============================
// JOURNEY SCREEN — MERGED
// ===============================
// FR-3.2.6:  Record location coordinates at predefined intervals
// FR-3.2.7:  Store location updates with timestamps
// FR-3.2.8:  Compute and display a safety status based on movement
// FR-3.2.10: Detect entry into geo-fenced zones
// FR-3.2.11: Generate alerts when user enters a high-risk zone
// FR-3.2.12: Notify monitoring authorities of geo-fence violations
// FR-3.2.13–15: AI anomaly detection + dynamic risk level display
// ===============================
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../models/risk_level.dart';
import '../data/city_coordinates.dart';
import '../services/journey_service.dart';
import '../services/geofence_service.dart';
import '../services/tracking_service.dart';
import '../services/risk_service.dart';
import '../services/ai_danger_service.dart';
import '../widgets/sleek_animation.dart';
import 'sos_screen.dart';

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
  final MapController    _mapController    = MapController();
  final JourneyService   _journeyService   = JourneyService();
  final GeofenceService  _geofenceService  = GeofenceService();
  final TrackingService  _trackingService  = TrackingService();

  List<LatLng> _routePoints   = [];
  LatLng? _startLatLng;
  LatLng? _endLatLng;
  bool _loadingRoute           = true;
  String? _errorMessage;
  bool _isMapReady             = false;
  List<GeofenceZone> _geofenceZones = [];

  // Live AI risk state — updated by TrackingService (FR-3.2.8 / FR-3.2.15)
  late RiskLevel _liveRiskLevel;
  bool _anomalyDetected  = false;
  String _anomalyReason  = '';

  // AI danger score from our scoring engine
  DangerAssessment? _aiAssessment;
  bool _aiLoading = false;

  // Track alerted zone IDs to avoid repeated popups (FR-3.2.11)
  final Set<String> _alertedZones = {};

  @override
  void initState() {
    super.initState();
    _liveRiskLevel = widget.riskLevel;
    _fetchRoute();      // resolves coords + route, then calls _runAiCheck with everything
    _loadGeofences();

    _journeyService.startJourney(
      startLocation: widget.startLocation,
      endLocation  : widget.endLocation,
      mode         : widget.mode,
      reference    : widget.reference,
      riskLevel    : widget.riskLevel.toString().split('.').last,
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

  // ── AI danger score check on journey start ─────────────────
  Future<void> _runAiCheck({double? lat, double? lng, List<Map<String,double>>? routeWaypoints}) async {
    if (!mounted) return;
    setState(() => _aiLoading = true);

    final service = AiDangerService();
    final result  = await service.assess(
      location        : widget.startLocation,
      destination     : widget.endLocation,
      lat             : lat,
      lng             : lng,
      transportMode   : widget.mode,
      routeWaypoints  : routeWaypoints,
    );

    if (!mounted) return;
    setState(() {
      _aiAssessment  = result;
      _aiLoading     = false;
      _liveRiskLevel = _riskLevelFromAiScore(result.score);
    });

    // Auto-trigger SOS if critical
    if (result.shouldTriggerSos && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => SosScreen(
          autoTrigger  : true,
          aiDangerScore: result.score,
          aiReason     : result.reasoning,
        ),
      ));
    }
  }

  // ── Called by TrackingService on each GPS + AI cycle ───────
  void _onRiskUpdate(RiskAnalysisResult result) {
    if (!mounted) return;
    // Never downgrade below what the AI danger score already determined.
    // Take whichever is the higher of the two risk levels.
    final aiFloor = _aiAssessment != null
        ? _riskLevelFromAiScore(_aiAssessment!.score)
        : RiskLevel.low;
    final effective = result.riskLevel.index >= aiFloor.index
        ? result.riskLevel
        : aiFloor;
    setState(() {
      _liveRiskLevel   = effective;
      _anomalyDetected = result.anomalyFlag;
      _anomalyReason   = result.reason;
    });

    // Geofence entry alert (FR-3.2.11 / FR-3.2.12)
    if (result.anomalyFlag && result.details.containsKey('geofence')) {
      final geoInfo  = result.details['geofence'] as Map<String, dynamic>;
      final zoneName = geoInfo['name'] ?? 'Unknown Zone';
      final zoneType = geoInfo['type'] ?? 'restricted';

      final matchedZone = _geofenceZones.firstWhere(
        (z) => z.name == zoneName,
        orElse: () => GeofenceZone(
          id: zoneName, name: zoneName, type: zoneType,
          centerLat: 0, centerLng: 0, radiusMeters: 0,
        ),
      );

      if (!_alertedZones.contains(matchedZone.id)) {
        _alertedZones.add(matchedZone.id);
        _showGeofenceAlert(zoneName, zoneType);
      }
    }

    // Non-geofence anomaly snackbar
    if (result.anomalyFlag && !result.details.containsKey('geofence')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(result.reason)),
          ]),
          backgroundColor: _colorForRisk(result.riskLevel),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  // ── Geofence alert dialog (FR-3.2.11) ──────────────────────
  void _showGeofenceAlert(String zoneName, String zoneType) {
    final isHighRisk = zoneType == 'high-risk';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(isHighRisk ? Icons.dangerous : Icons.warning_amber_rounded,
              color: isHighRisk ? Colors.red : Colors.orange),
          const SizedBox(width: 8),
          const Expanded(child: Text('Zone Alert')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You have entered a ${zoneType.replaceAll('-', ' ').toUpperCase()} zone:'),
            const SizedBox(height: 8),
            Text(zoneName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (isHighRisk)
              const Text('⚠️  Authorities have been notified. Please move to a safe area immediately.',
                  style: TextStyle(color: Colors.red))
            else
              const Text('Please exercise caution in this area.',
                  style: TextStyle(color: Colors.orange)),
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
      LatLng? end   = CityCoordinates.get(widget.endLocation);

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
              routePoints  = coords.map((c) => LatLng(c[1], c[0])).toList();
            }
          }
        } catch (e) { debugPrint('OSRM error: $e'); }

        if (!mounted) return;
        setState(() {
          _startLatLng  = start;
          _endLatLng    = end;
          _routePoints  = routePoints;
          _loadingRoute = false;
        });
        if (_isMapReady) _fitRoute();

        // Sample up to 20 waypoints from the full route for AI scoring
        final waypointSample = <Map<String, double>>[];
        final step = math.max(1, routePoints.length ~/ 20);
        for (int i = 0; i < routePoints.length; i += step) {
          waypointSample.add({'lat': routePoints[i].latitude, 'lng': routePoints[i].longitude});
        }
        _runAiCheck(lat: start!.latitude, lng: start.longitude, routeWaypoints: waypointSample);
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

  // ── Helpers ────────────────────────────────────────────────
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

  // ── Map AI danger score → RiskLevel (keeps badge in sync) ──
  RiskLevel _riskLevelFromAiScore(int score) {
    if (score < 40) return RiskLevel.low;
    if (score < 60) return RiskLevel.medium;
    return RiskLevel.high; // covers 'danger' (60–74) and 'critical' (75+)
  }

  // ── AI score colour ────────────────────────────────────────
  Color _aiColor(int score) {
    if (score < 40) return const Color(0xFF22C55E);
    if (score < 60) return const Color(0xFFF59E0B);
    if (score < 75) return const Color(0xFFEF4444);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Journey Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [

          // ── Live AI Risk Banner (FR-3.2.8/15) ──────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            color: _riskColor.withOpacity(0.12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Icon(
                _anomalyDetected ? Icons.warning_amber_rounded : Icons.shield,
                color: _riskColor, size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Safety Status: $_riskLabel',
                      style: TextStyle(color: _riskColor,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_anomalyDetected && _anomalyReason.isNotEmpty)
                    Text(_anomalyReason,
                        style: TextStyle(color: _riskColor, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              )),
              if (_anomalyDetected)
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: _riskColor, shape: BoxShape.circle)),
            ]),
          ),

          // ── Map ─────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: _loadingRoute
                ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                : _startLatLng == null || _endLatLng == null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(_errorMessage ?? 'Could not load map route',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
                      ))
                    : Stack(children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _startLatLng!,
                            initialZoom: 12,
                            minZoom: 2, maxZoom: 18,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                            onMapReady: () { _isMapReady = true; _fitRoute(); },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.atlaswatch.app',
                              retinaMode: RetinaMode.isHighDensity(context),
                            ),
                            PolylineLayer(polylines: [
                              Polyline(
                                points: _routePoints,
                                strokeWidth: 5.0,
                                color: Colors.blueAccent,
                                borderStrokeWidth: 2.0,
                                borderColor: Colors.blue.shade900,
                              ),
                            ]),
                            MarkerLayer(markers: [
                              Marker(
                                point: _startLatLng!, width: 40, height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.2),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.circle, color: Colors.blue, size: 14),
                                ),
                              ),
                              Marker(
                                point: _endLatLng!, width: 50, height: 50,
                                child: Icon(Icons.location_on_rounded,
                                    color: Colors.red.shade600, size: 40),
                              ),
                            ]),
                            // Geofence overlays (FR-3.2.10/11)
                            if (_geofenceZones.isNotEmpty)
                              CircleLayer(circles: _geofenceZones.map((zone) {
                                final color = _geofenceColor(zone.type);
                                return CircleMarker(
                                  point: LatLng(zone.centerLat, zone.centerLng),
                                  radius: zone.radiusMeters,
                                  useRadiusInMeter: true,
                                  color: color.withOpacity(0.15),
                                  borderColor: color,
                                  borderStrokeWidth: 2.0,
                                );
                              }).toList()),
                            if (_geofenceZones.isNotEmpty)
                              MarkerLayer(markers: _geofenceZones.map((zone) => Marker(
                                point: LatLng(zone.centerLat, zone.centerLng),
                                width: 120, height: 30,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _geofenceColor(zone.type).withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(zone.name,
                                      style: const TextStyle(color: Colors.white,
                                          fontSize: 10, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              )).toList()),
                          ],
                        ),
                        // Zoom controls
                        Positioned(
                          right: 16, top: 16,
                          child: Column(children: [
                            _mapButton(Icons.add_rounded, () => _mapController.move(
                                _mapController.camera.center, _mapController.camera.zoom + 1)),
                            const SizedBox(height: 8),
                            _mapButton(Icons.remove_rounded, () => _mapController.move(
                                _mapController.camera.center, _mapController.camera.zoom - 1)),
                            const SizedBox(height: 8),
                            _mapButton(Icons.my_location_rounded, _fitRoute),
                          ]),
                        ),
                      ]),
          ),

          // ── Bottom info panel ────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
                  blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status badge + live indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(),
                    const Row(children: [
                      Icon(Icons.circle, color: Colors.green, size: 8),
                      SizedBox(width: 6),
                      Text('LIVE', style: TextStyle(color: Colors.grey,
                          fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Journey info
                _infoItem(Icons.my_location_rounded, 'ORIGIN', widget.startLocation),
                const Padding(
                  padding: EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  child: Icon(Icons.more_vert, size: 16, color: Colors.blueGrey),
                ),
                _infoItem(Icons.location_on_outlined, 'DESTINATION', widget.endLocation),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(child: _metaInfo('TRAVEL MODE', widget.mode,
                      icon: Icons.directions_bus_filled_outlined)),
                  if (widget.reference.isNotEmpty)
                    Expanded(child: _metaInfo('REFERENCE', widget.reference,
                        icon: Icons.tag_rounded)),
                ]),

                // AI danger badge
                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),
                _buildAiBadge(),

                // Geofence legend
                if (_geofenceZones.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _legendDot(Colors.green, 'Safe'),
                    const SizedBox(width: 12),
                    _legendDot(Colors.orange, 'Restricted'),
                    const SizedBox(width: 12),
                    _legendDot(Colors.red, 'High-Risk'),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI badge in info panel ─────────────────────────────────
  void _showAiScoreSheet() {
    if (_aiAssessment == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AiScoreSheet(assessment: _aiAssessment!, onRefresh: () {
        Navigator.pop(context);
        _runAiCheck(lat: _startLatLng?.latitude, lng: _startLatLng?.longitude);
      }),
    );
  }

  Widget _buildAiBadge() {
    if (_aiLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          SizedBox(height: 14, width: 14,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.blue.shade400)),
          const SizedBox(width: 10),
          const Text('AI assessing route danger...', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      );
    }
    if (_aiAssessment == null) return const SizedBox.shrink();

    final a     = _aiAssessment!;
    final color = _aiColor(a.score);
    final isCritical = a.score >= 75;

    Color bgColor;
    if (a.score < 40)      bgColor = const Color(0xFF041A0D);
    else if (a.score < 60) bgColor = const Color(0xFF1A1000);
    else                   bgColor = const Color(0xFF1A0404);

    return GestureDetector(
      onTap: _showAiScoreSheet,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.45), width: 1.5),
          boxShadow: isCritical
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 20, spreadRadius: 1)]
              : [],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                isCritical ? Icons.gpp_bad_rounded
                    : a.score >= 60 ? Icons.warning_rounded : Icons.verified_user_rounded,
                color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI DANGER SCORE', style: TextStyle(color: color, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Text('powered by Built-in AI',
                  style: TextStyle(color: Colors.white24, fontSize: 8)),
            ])),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: a.score.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, val, __) => Text('${val.toInt()}/100',
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new_rounded, color: Colors.white24, size: 16),
          ]),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: a.score / 100),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (_, val, __) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(value: val, minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(color)),
            ),
          ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withOpacity(0.35))),
              child: Text(a.severity.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(a.reasoning,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 8),
          const Text('Tap for full breakdown',
              style: TextStyle(color: Colors.white24, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: _riskColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.security_rounded, color: _riskColor, size: 14),
        const SizedBox(width: 8),
        Text(_riskLabel.toUpperCase(),
            style: TextStyle(color: _riskColor, fontSize: 12,
                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: Colors.grey.shade600, size: 20),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9,
            fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  Widget _metaInfo(String label, String value, {required IconData icon}) {
    return Row(children: [
      Icon(icon, color: Colors.blue.shade400, size: 18),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10,
            fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        Text(value, style: const TextStyle(color: Colors.white,
            fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ]);
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
        child: SizedBox(width: 44, height: 44,
            child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// AI SCORE BOTTOM SHEET — matches dashboard AiRiskMonitor style
// ══════════════════════════════════════════════════════════════
class _AiScoreSheet extends StatelessWidget {
  final DangerAssessment assessment;
  final VoidCallback onRefresh;
  const _AiScoreSheet({required this.assessment, required this.onRefresh});

  Color _colorFor(int s) {
    if (s < 40) return const Color(0xFF22C55E);
    if (s < 60) return const Color(0xFFF59E0B);
    if (s < 75) return const Color(0xFFEF4444);
    return const Color(0xFFDC2626);
  }

  Color get _bgColor {
    if (assessment.score < 40) return const Color(0xFF041A0D);
    if (assessment.score < 60) return const Color(0xFF1A1000);
    return const Color(0xFF1A0404);
  }

  @override
  Widget build(BuildContext context) {
    final a     = assessment;
    final color = _colorFor(a.score);
    final isCritical = a.score >= 75;

    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle bar
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // ── Header ────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(
                isCritical ? Icons.gpp_bad_rounded
                    : a.score >= 60 ? Icons.warning_rounded : Icons.verified_user_rounded,
                color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI DANGER SCORE', style: TextStyle(color: color, fontSize: 12,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Text('powered by ${a.aiSourceLabel}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${a.score}', style: TextStyle(color: color, fontSize: 44,
                  fontWeight: FontWeight.w900, height: 1)),
              Text('/100', style: TextStyle(color: color.withOpacity(0.5),
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ]),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: a.score / 100, minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
          const SizedBox(height: 14),

          // Severity + reasoning
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.35))),
              child: Text(a.severity.toUpperCase(),
                  style: TextStyle(color: color, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(a.reasoning,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.45))),
          ]),

          if (isCritical) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.45))),
              child: const Row(children: [
                Icon(Icons.emergency_rounded, color: Colors.red, size: 15),
                SizedBox(width: 8),
                Expanded(child: Text('AUTO-SOS TRIGGERED — Alerting emergency contacts',
                    style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
              ]),
            ),
          ],

          const SizedBox(height: 22),
          Divider(color: color.withOpacity(0.15), height: 1),
          const SizedBox(height: 18),

          // ── Score breakdown ────────────────────────────────
          Text('SCORE BREAKDOWN', style: TextStyle(color: color.withOpacity(0.7),
              fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ...a.subScores.map((sub) {
            final sc = _colorFor(sub.score);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                SizedBox(width: 30, child: Text(sub.icon,
                    style: const TextStyle(fontSize: 20), textAlign: TextAlign.center)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sub.label, style: const TextStyle(color: Colors.white70,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(sub.detail, style: const TextStyle(color: Colors.white30, fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${sub.score}', style: TextStyle(color: sc,
                      fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: sub.score / 100, minHeight: 5,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(sc)),
                  ),
                ])),
              ]),
            );
          }),

          // ── Risk factors ───────────────────────────────────
          if (a.riskFactors.where((f) => !f.contains('backend offline') && !f.contains('On-device')).isNotEmpty) ...[
            const SizedBox(height: 6),
            Divider(color: Colors.white.withOpacity(0.06), height: 1),
            const SizedBox(height: 16),
            Text('RISK FACTORS', style: TextStyle(color: Colors.orange.withOpacity(0.8),
                fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            ...a.riskFactors.where((f) => !f.contains('backend offline') && !f.contains('On-device')).map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.circle, size: 5, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: TextStyle(color: Colors.orange.shade200, fontSize: 12))),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 14),

          // ── Refresh ────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Scores update every 60s or on refresh',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
            GestureDetector(
              onTap: onRefresh,
              child: Row(children: [
                const Icon(Icons.refresh_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 4),
                Text('Refresh', style: TextStyle(color: color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}