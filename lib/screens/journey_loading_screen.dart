import 'package:flutter/material.dart';
import '../models/risk_level.dart';
import 'journey_screen.dart';

class JourneyLoadingScreen extends StatefulWidget {
  final RiskLevel riskLevel;
  final String startLocation;
  final String endLocation;
  final String mode;
  final String reference;

  const JourneyLoadingScreen({
    super.key,
    required this.riskLevel,
    required this.startLocation,
    required this.endLocation,
    required this.mode,
    required this.reference,
  });

  @override
  State<JourneyLoadingScreen> createState() => _JourneyLoadingScreenState();
}

class _JourneyLoadingScreenState extends State<JourneyLoadingScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyScreen(
            riskLevel: widget.riskLevel,
            startLocation: widget.startLocation,
            endLocation: widget.endLocation,
            mode: widget.mode,
            reference: widget.reference,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
