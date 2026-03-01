import 'package:flutter/material.dart';
import '../models/risk_level.dart';
import '../services/location_service.dart';
import 'journey_loading_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final result = await LocationService().fetchCurrentLocation();
    if (!mounted) return;

    setState(() {
      _loadingLocation = false;
      if (result?.address != null) {
        _startController.text = result!.address!;
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
                const Text(
                  'Plan Your Trip',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set your destination and travel details for live monitoring.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 32),

                // --- FORM CARD ---
                Container(
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

                const SizedBox(height: 48),

                // --- ACTION BUTTON ---
                SizedBox(
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
}
