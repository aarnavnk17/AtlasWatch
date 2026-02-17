import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/risk_level.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/crime_service.dart';
import '../services/risk_service.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'journey_details_screen.dart';
import 'sos_screen.dart';
import 'contact_manager_screen.dart';
import '../services/geofence_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  RiskLevel _riskLevel = RiskLevel.low;

  String? _locationName;
  bool _loadingLocation = true;
  
  // Default to a neutral location (e.g. 0,0) until we fetch the real one.
  LatLng _currentLatLng = const LatLng(0, 0);
  
  final TextEditingController _locationController = TextEditingController();
  final GeofenceService _geofenceService = GeofenceService();
  List<Map<String, dynamic>> _safeZones = [];

  @override
  void initState() {
    super.initState();
    _fetchLocationAndRisk();
    _loadSafeZones();
  }

  Future<void> _loadSafeZones() async {
      final zones = await _geofenceService.getRegisteredGeofences();
      setState(() => _safeZones = zones);
  }

  Future<void> _addCurrentAsSafeZone() async {
      final String id = "Zone_${DateTime.now().millisecondsSinceEpoch}";
      await _geofenceService.addSafeZone(
          id: id,
          latitude: _currentLatLng.latitude,
          longitude: _currentLatLng.longitude,
          radiusInMeters: 200, // 200m radius
      );
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Safe Zone added at current location!')),
      );
      _loadSafeZones();
  }

  Future<void> _removeSafeZone(String id) async {
      await _geofenceService.removeZone(id);
      _loadSafeZones();
  }

  
  Future<void> _simulateLocation(String customLocation) async {
      if (customLocation.isEmpty) return;
      
      setState(() {
          _loadingLocation = true;
          _locationName = customLocation;
      });

      // 1. Geocode the address to get coordinates
      try {
          List<Location> locations = await locationFromAddress(customLocation);
          if (locations.isNotEmpty) {
              final loc = locations.first;
              final newLatLng = LatLng(loc.latitude, loc.longitude);
              setState(() {
                  _currentLatLng = newLatLng;
              });
              

          }
      } catch (e) {
          debugPrint('Error geocoding custom location: $e');
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Could not find location: $customLocation')),
          );
      }

      // 2. Fetch Risk Score
      final crimeService = CrimeService();
      final riskService = RiskService();

      final score = await crimeService.fetchCrimeScore(customLocation);

      if (!mounted) return;

      setState(() {
        _riskLevel = riskService.calculateRisk(score);
        _loadingLocation = false;
      });
  }

  Future<void> _fetchLocationAndRisk() async {
    final locationService = LocationService();
    
    // Fetch location result which contains both position and address
    final result = await locationService.fetchCurrentLocation();
    
    if (!mounted) return;

    if (result != null) {
      final newLatLng = LatLng(result.position.latitude, result.position.longitude);
      setState(() {
        _locationName = result.address;
        _loadingLocation = false;
        _currentLatLng = newLatLng;
      });
      


      // Fetch Risk if address is available
      if (result.address != null) {
        final crimeService = CrimeService();
        final riskService = RiskService();

        final score = await crimeService.fetchCrimeScore(result.address!);

        if (!mounted) return;

        setState(() {
          _riskLevel = riskService.calculateRisk(score);
        });
      }
    } else {
        setState(() {
            _loadingLocation = false;
            _locationName = null;
        });
    }
  }
  
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
            // 🚦 Risk Banner
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

            // 📍 Location
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
                            onPressed: () {
                              setState(() {
                                _loadingLocation = true;
                              });
                              _fetchLocationAndRisk();
                            },
                            tooltip: 'Refresh Location',
                          ),
                        ],
                      ),
                      if (_locationName != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Lat: ${_currentLatLng.latitude.toStringAsFixed(4)}, Lng: ${_currentLatLng.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                    ],
                  ),

            const SizedBox(height: 10),

            // 🏘️ geofence management
            ExpansionTile(
              leading: const Icon(Icons.location_on, color: Colors.teal),
              title: const Text('Manage Safe Zones'),
              subtitle: Text('${_safeZones.length} zones active'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_location),
                        label: const Text('Add Current Location as Safe Zone'),
                        onPressed: _loadingLocation ? null : _addCurrentAsSafeZone,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._safeZones.map((zone) => ListTile(
                        dense: true,
                        title: Text('Radius: ${zone['radius']}m'),
                        subtitle: Text('Lat: ${zone['lat'].toStringAsFixed(3)}, Lng: ${zone['lng'].toStringAsFixed(3)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeSafeZone(zone['id']),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            


            const SizedBox(height: 20), // Reduced from 30 to fit map

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JourneyDetailsScreen(riskLevel: _riskLevel),
                  ),
                );
              },
              child: const Text('Start Journey'),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactManagerScreen()),
                );
              },
              child: const Text('Emergency Contacts'),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileSetupScreen(isEditMode: true),
                  ),
                );
              },
              child: const Text('My Profile'),
            ),

            const Spacer(),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SosScreen()),
                );
              },
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
