// ===============================
// SOS ACTIVE SCREEN
// ===============================
// Shown after SOS is confirmed
// ===============================

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class SosActiveScreen extends StatefulWidget {
  final bool playSiren;

  const SosActiveScreen({super.key, this.playSiren = false});

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.playSiren) {
      try {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.alarm,
          looping: true,
          volume: 1.0,
          asAlarm: true, // This forces sound even if phone is on silent
        );
      } catch (e) {
        debugPrint('Error playing siren sound: $e');
      }
    }
  }

  @override
  void dispose() {
    if (widget.playSiren) {
      FlutterRingtonePlayer().stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- ACTIVE PULSE ---
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_rounded, size: 100, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 48),

              const Text(
                'SOS IS ACTIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your live location and medical profile\nare being shared with your emergency\ncontacts and local authorities.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
              ),

              const Spacer(),

              // --- SAFE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                    shadowColor: Colors.black45,
                  ),
                  onPressed: () {
                    if (widget.playSiren) {
                      FlutterRingtonePlayer().stop();
                    }
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text(
                    "I'M NOW SAFE",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Press only after securing yourself.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
