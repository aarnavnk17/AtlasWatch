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
      appBar: AppBar(title: const Text('Journey Details')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _loadingLocation
                  ? const LinearProgressIndicator()
                  : const SizedBox.shrink(),

              TextFormField(
                controller: _startController,
                decoration: const InputDecoration(labelText: 'Start Location'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _endController,
                decoration: const InputDecoration(labelText: 'End Location'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _mode,
                items: const [
                  DropdownMenuItem(value: 'Car', child: Text('Car')),
                  DropdownMenuItem(value: 'Train', child: Text('Train')),
                  DropdownMenuItem(value: 'Flight', child: Text('Flight')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
                decoration: const InputDecoration(labelText: 'Mode of Travel'),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle / Train / Flight Number',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
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
                child: const Text('Begin Journey'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
