import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/risk_level.dart';
import '../services/location_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/sleek_animation.dart';
import 'journey_loading_screen.dart';
import 'dart:async';

class JourneyDetailsScreen extends StatefulWidget {
  final RiskLevel riskLevel;

  const JourneyDetailsScreen({super.key, required this.riskLevel});

  @override
  State<JourneyDetailsScreen> createState() => _JourneyDetailsScreenState();
}

class _JourneyDetailsScreenState extends State<JourneyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _referenceController = TextEditingController();
  String _mode = 'Car';
  bool _loadingLocation = true;

  final MapController _mapController = MapController();
  LatLng? _previewLatLng;
  final GeocodingService _geocoder = GeocodingService();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _endController.addListener(_onDestinationChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _onDestinationChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_endController.text.length < 3) return;
      _updatePreview(_endController.text);
    });
  }

  Future<void> _updatePreview(String query) async {
    try {
      final loc = await _geocoder.resolveLocation(query);
      if (loc != null && mounted) {
        setState(() => _previewLatLng = loc);
        _mapController.move(loc, 16.5); // High zoom for building names
      }
    } catch (e) {
      debugPrint('Geocoding preview error: $e');
    }
  }

  Future<void> _fetchLocation() async {
    final result = await LocationService().fetchCurrentLocation();
    if (!mounted) return;

    setState(() {
      _loadingLocation = false;
      if (result?.address != null) {
        _startController.text = result!.address!;
      }
      if (result != null) {
        final loc = LatLng(result.position.latitude, result.position.longitude);
        _previewLatLng = loc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Journey Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SleekAnimation(
                  delay: Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan Your Trip',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Set your destination and travel details for live monitoring.',
                        style: TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // --- FORM CARD ---
                SleekAnimation(
                  delay: const Duration(milliseconds: 400),
                  type: SleekAnimationType.slide,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.03)),
                    ),
                    child: Column(
                      children: [
                        _buildFieldLabel('Starting Point'),
                        TextFormField(
                          controller: _startController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Current Location', Icons.my_location_rounded),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),

                        _buildFieldLabel('Destination'),
                        TextFormField(
                          controller: _endController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Where are you going?', Icons.location_on_outlined),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),

                        // --- MAP PREVIEW ---
                        _buildMapPreview(),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Travel Mode'),
                        const SizedBox(height: 12),
                        _buildModeSelector(),
                        const SizedBox(height: 24),

                        _buildFieldLabel('Vehicle / Number'),
                        TextFormField(
                          controller: _referenceController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('e.g. MH01-AB-1234 or AI 101', Icons.directions_bus_filled_outlined),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // --- ACTION BUTTON ---
                SleekAnimation(
                  delay: const Duration(milliseconds: 600),
                  type: SleekAnimationType.slide,
                  slideOffset: const Offset(0, 0.1),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JourneyLoadingScreen(
                              riskLevel: widget.riskLevel,
                              startLocation: _startController.text,
                              endLocation: _endController.text,
                              mode: _mode,
                              reference: _referenceController.text,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text(
                        'START TRACKING',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = ['Car', 'Train', 'Flight', 'Walk'];
    final icons = [Icons.directions_car, Icons.train, Icons.flight, Icons.directions_walk];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: modes.asMap().entries.map((entry) {
        final isSelected = _mode == entry.value;
        return GestureDetector(
          onTap: () => setState(() => _mode = entry.value),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.withOpacity(0.15) : const Color(0xFF2C2C2C),
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 1.5),
                ),
                child: Icon(icons[entry.key], color: isSelected ? Colors.blue.shade400 : Colors.grey.shade600, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                entry.value,
                style: TextStyle(color: isSelected ? Colors.blue.shade400 : Colors.grey.shade600, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      prefixIconColor: WidgetStateColor.resolveWith((states) => 
        states.contains(WidgetState.focused) ? Colors.blue.shade400 : Colors.grey.shade600
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _previewLatLng ?? const LatLng(19.0760, 72.8777), // Default: Mumbai if null
              initialZoom: 14,
              minZoom: 2,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.atlaswatch.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              if (_previewLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _previewLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on_rounded, color: Colors.blue, size: 30),
                    ),
                  ],
                ),
            ],
          ),
          // --- ZOOM OVERLAY ---
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _miniMapButton(Icons.add_rounded, () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                }),
                const SizedBox(height: 6),
                _miniMapButton(Icons.remove_rounded, () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                }),
              ],
            ),
          ),
          if (_previewLatLng == null)
            const Center(
              child: Text(
                'Enter destination to see preview',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniMapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
