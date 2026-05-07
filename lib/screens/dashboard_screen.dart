import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../models/risk_level.dart';
import '../data/city_coordinates.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/crime_service.dart';
import '../services/risk_service.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'journey_details_screen.dart';
import 'sos_screen.dart';
import 'contact_manager_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RiskLevel _riskLevel = RiskLevel.low;
  String? _locationName;
  bool _loadingLocation = true;
  LatLng _currentLatLng = const LatLng(0, 0);

  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLocationAndRisk();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // ── Simulate location (testing) ────────────────────────────────────────────

  Future<void> _simulateLocation(String customLocation) async {
    if (customLocation.isEmpty) return;

    setState(() {
      _loadingLocation = true;
      _locationName = customLocation;
    });

    // 1. Resolve coordinates — local lookup first, geocoding as fallback
    LatLng? resolved = CityCoordinates.get(customLocation);

    if (resolved == null) {
      try {
        final locs = await locationFromAddress(customLocation);
        if (locs.isNotEmpty) {
          resolved = LatLng(locs.first.latitude, locs.first.longitude);
        }
      } catch (e) {
        debugPrint('Geocoding failed for simulate: $e');
      }
    }

    if (resolved != null) {
      setState(() => _currentLatLng = resolved!);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find coordinates for: $customLocation')),
      );
    }

    // 2. Fetch risk score
    final crimeService = CrimeService();
    final riskService = RiskService();
    final score = await crimeService.fetchCrimeScore(customLocation);

    if (!mounted) return;

    setState(() {
      _riskLevel = riskService.calculateRisk(score);
      _loadingLocation = false;
    });
  }

  // ── Real location + risk ───────────────────────────────────────────────────

  Future<void> _fetchLocationAndRisk() async {
    try {
      final result = await LocationService().fetchCurrentLocation();
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _loadingLocation = false;
          _currentLatLng =
              LatLng(result.position.latitude, result.position.longitude);
          _locationName = result.address;
        });

        if (result.address != null) {
          final score =
              await CrimeService().fetchCrimeScore(result.address!);
          if (!mounted) return;
          setState(() {
            _riskLevel = RiskService().calculateRisk(score);
          });
        }
      } else {
        setState(() {
          _loadingLocation = false;
          _locationName = null;
        });
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationName = 'Location unavailable';
        });
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color get _riskColor {
    switch (_riskLevel) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }

  String get _riskLabel {
    switch (_riskLevel) {
      case RiskLevel.low:
        return 'Low Risk Area';
      case RiskLevel.medium:
        return 'Medium Risk Area';
      case RiskLevel.high:
        return 'High Risk Area';
    }
  }

  Future<void> _logout() async {
    await SessionService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AtlasWatch'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Risk banner
            Container(
              padding: const EdgeInsets.all(16),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Location display
            _loadingLocation
                ? const LinearProgressIndicator()
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _locationName == null
                                  ? 'Location unavailable'
                                  : 'Current Location: $_locationName',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Refresh Location',
                            onPressed: () {
                              setState(() => _loadingLocation = true);
                              _fetchLocationAndRisk();
                            },
                          ),
                        ],
                      ),
                      if (_locationName != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Lat: ${_currentLatLng.latitude.toStringAsFixed(4)}, '
                            'Lng: ${_currentLatLng.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                    ],
                  ),

            const SizedBox(height: 10),

            // Simulate location (dev)
            ExpansionTile(
              title: const Text(
                'Enter Location',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            hintText: 'Enter city (e.g. Mumbai)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _simulateLocation(_locationController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Simulate'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      JourneyDetailsScreen(riskLevel: _riskLevel),
                ),
              ),
              child: const Text('Start Journey'),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ContactManagerScreen()),
              ),
              child: const Text('Emergency Contacts'),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ProfileSetupScreen(isEditMode: true),
                ),
              ),
              child: const Text('My Profile'),
            ),

            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SosScreen()),
              ),
              child: const Text(
                'SOS EMERGENCY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
