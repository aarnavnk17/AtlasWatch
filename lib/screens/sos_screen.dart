import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_active_screen.dart';
import '../services/contact_service.dart';
import '../services/session_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSending = false;
  bool _playSiren = true;

  Future<void> _sendSos() async {
    setState(() => _isSending = true);

    try {
      // 1. Get Location (High Accuracy)
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // 2. Fetch Contacts & Profile
      final contactService = ContactService();
      final sessionService = SessionService();
      
      final contacts = await contactService.getContacts();
      final profile = await sessionService.loadProfile();
      
      // 3. Prepare SMS
      List<String> recipients = [];
      for (var c in contacts) {
        recipients.add(c.phone);
      }

      if (recipients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No emergency contacts found. Please add some first!')),
          );
        }
        return;
      }

      // Build medical summary for the message
      String medicalInfo = "";
      if (profile != null) {
        final name = profile['fullName'] ?? "User";
        final blood = profile['bloodGroup'] ?? "Unknown";
        final allergies = profile['allergies'] ?? "None";
        final conditions = profile['medicalConditions'] ?? "None";
        
        medicalInfo = "\n\nCRITICAL INFO:\nName: $name\nBlood: $blood\nAllergies: $allergies\nConditions: $conditions";
      }

      final String message = "HELP! I am in danger. My location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}$medicalInfo";
      
      final String path = recipients.join(',');
      
      final Uri smsLaunchUri = Uri(
        scheme: 'sms',
        path: path,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      // 4. Launch SMS App
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      } else {
        // Fallback for simulators or no SMS app
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not launch SMS app (Simulator?)')),
           );
         }
      }

      // 4. Navigate to Active Screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SosActiveScreen(playSiren: _playSiren)),
        );
      }
    } catch (e) {
      debugPrint("Error sending SOS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'Emergency SOS',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pressing the button below will alert your\nemergency contacts immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              
              const Spacer(),

              // --- BIG SOS BUTTON ---
              GestureDetector(
                onTap: _isSending ? null : _sendSos,
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isSending ? Colors.grey.shade900 : const Color(0xFFE53935),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.3),
                        blurRadius: _isSending ? 0 : 40,
                        spreadRadius: _isSending ? 0 : 10,
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 8),
                  ),
                  child: Center(
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                              const SizedBox(height: 8),
                              const Text(
                                'HELP',
                                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const Spacer(),

              // --- SIREN CARD ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.03)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.volume_up_rounded, color: Colors.blue.shade400, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alarm Siren', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Plays a loud sound locally', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _playSiren,
                      activeColor: Colors.blue.shade400,
                      onChanged: (val) => setState(() => _playSiren = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
