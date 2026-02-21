import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_active_screen.dart';
import '../services/contact_service.dart';

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

      // 2. Fetch Contacts
      final contactService = ContactService();
      final contacts = await contactService.getContacts();
      
      // 3. Prepare SMS
      // Recipients: All emergency contacts (Testing mode: Police removed)
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

      final String message = "HELP! I am in danger. My location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      
      // For cross-platform SMS with multiple recipients, we join with comma or semicolon
      // Android usually uses comma, iOS uses comma. 
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
      backgroundColor: Colors.red.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 120, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'EMERGENCY MODE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Pressing confirm will send your live location to your emergency contacts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Sound Alarm Siren',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Plays a loud siren to attract attention',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  value: _playSiren,
                  onChanged: (bool value) {
                    setState(() {
                      _playSiren = value;
                    });
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.red.shade300,
                  inactiveThumbColor: Colors.white54,
                  inactiveTrackColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 30),
              _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _sendSos,
                        child: const Text(
                          'CONFIRM SOS',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
