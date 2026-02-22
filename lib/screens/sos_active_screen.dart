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
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'SOS Activated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Emergency assistance has been alerted.\nStay calm and remain in a safe place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                       if (widget.playSiren) {
                         FlutterRingtonePlayer().stop();
                       }
                       Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text(
                      "I'M SAFE",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
