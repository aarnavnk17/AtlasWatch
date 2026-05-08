import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_active_screen.dart';
import '../services/contact_service.dart';
import '../services/backend_service.dart';
import '../services/session_service.dart';
import '../widgets/sleek_animation.dart';

class SosScreen extends StatefulWidget {
  /// When true, SOS fires automatically — triggered by the AI engine.
  final bool autoTrigger;
  final int? aiDangerScore;
  final String? aiReason;

  const SosScreen({
    super.key,
    this.autoTrigger = false,
    this.aiDangerScore,
    this.aiReason,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _isSending = false;
  bool _playSiren = true;
  bool _cancelled = false;
  int _countdown = 5;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    if (widget.autoTrigger) _startAutoCountdown();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startAutoCountdown() async {
    for (int i = 5; i > 0; i--) {
      if (!mounted || _cancelled) return;
      setState(() => _countdown = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted || _cancelled) return;
    _sendSos();
  }

  Future<void> _sendSos() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // Log SOS to backend
      try {
        final session = SessionService();
        final email = await session.getEmail();
        if (email != null) {
          await BackendService.post(
            '/sos',
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email'  : email,
              'lat'    : position.latitude,
              'lng'    : position.longitude,
              'trigger': widget.autoTrigger ? 'ai_auto' : 'manual',
              if (widget.aiDangerScore != null) 'aiScore': widget.aiDangerScore,
            }),
          );
        }
      } catch (e) {
        debugPrint('SOS backend log failed: $e');
      }

      final contactService = ContactService();
      final sessionService = SessionService();
      final contacts = await contactService.getContacts();
      final profile  = await sessionService.loadProfile();

      List<String> recipients = contacts.map((c) => c.phone).toList();

      if (recipients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No emergency contacts found. Please add some first!')),
          );
        }
        setState(() => _isSending = false);
        return;
      }

      String medicalInfo = '';
      if (profile != null) {
        final name       = profile['fullName']        ?? 'User';
        final blood      = profile['bloodGroup']      ?? 'Unknown';
        final allergies  = profile['allergies']       ?? 'None';
        final conditions = profile['medicalConditions'] ?? 'None';
        medicalInfo = '\n\nCRITICAL INFO:\nName: $name\nBlood: $blood\nAllergies: $allergies\nConditions: $conditions';
      }

      final aiContext = widget.autoTrigger && widget.aiDangerScore != null
          ? '\n\n⚠️ AI DANGER SCORE: ${widget.aiDangerScore}/100 — Auto-triggered by AtlasWatch AI'
          : '';

      final message =
          'HELP! I am in danger. My location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}$medicalInfo$aiContext';

      final Uri smsUri = Uri(
        scheme: 'sms',
        path: recipients.join(','),
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch SMS app')),
          );
        }
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => SosActiveScreen(
            playSiren    : _playSiren,
            aiTriggered  : widget.autoTrigger,
            aiDangerScore: widget.aiDangerScore,
          ),
        ));
      }
    } catch (e) {
      debugPrint('Error sending SOS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSending = false);
      }
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
          onPressed: () {
            _cancelled = true;
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Title
              SleekAnimation(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    Text(
                      widget.autoTrigger ? 'AI AUTO-SOS' : 'Emergency SOS',
                      style: const TextStyle(color: Colors.white, fontSize: 32,
                          fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.autoTrigger
                          ? 'Critical danger detected by AI.\nAlerting your emergency contacts.'
                          : 'Pressing the button below will alert your\nemergency contacts immediately.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),

              // AI reason card
              if (widget.autoTrigger && widget.aiReason != null) ...[
                const SizedBox(height: 20),
                SleekAnimation(
                  delay: const Duration(milliseconds: 250),
                  type: SleekAnimationType.slide,
                  slideOffset: const Offset(0, 0.1),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.psychology_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI ASSESSMENT — Score ${widget.aiDangerScore}/100',
                                style: const TextStyle(color: Colors.red, fontSize: 11,
                                    fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(widget.aiReason!,
                                style: const TextStyle(color: Colors.white70,
                                    fontSize: 13, height: 1.4)),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // SOS button or countdown
              SleekAnimation(
                delay: const Duration(milliseconds: 400),
                type: SleekAnimationType.scale,
                child: widget.autoTrigger && !_isSending
                    ? _buildCountdown()
                    : _buildSosButton(),
              ),

              const Spacer(),

              // Cancel (auto-trigger only)
              if (widget.autoTrigger && !_isSending && !_cancelled) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() => _cancelled = true);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white54, size: 18),
                  label: const Text('Cancel — I am safe',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
                const SizedBox(height: 8),
              ],

              // Siren toggle (manual only)
              if (!widget.autoTrigger)
                SleekAnimation(
                  delay: const Duration(milliseconds: 600),
                  type: SleekAnimationType.slide,
                  slideOffset: const Offset(0, 0.1),
                  child: Container(
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
                          decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.volume_up_rounded,
                              color: Colors.blue.shade400, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alarm Siren', style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Plays a loud sound locally',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        )),
                        Switch.adaptive(
                          value: _playSiren,
                          activeColor: Colors.blue.shade400,
                          onChanged: (val) => setState(() => _playSiren = val),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
      child: Stack(alignment: Alignment.center, children: [
        Container(
          height: 200, width: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A0000),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5),
                blurRadius: 50, spreadRadius: 10)],
            border: Border.all(color: Colors.red.withOpacity(0.6), width: 4),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$_countdown', style: const TextStyle(color: Colors.red,
              fontSize: 64, fontWeight: FontWeight.w900)),
          const Text('SENDING SOS', style: TextStyle(color: Colors.white70,
              fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ]),
      ]),
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTap: _isSending ? null : _sendSos,
      child: Container(
        height: 200, width: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isSending ? Colors.grey.shade900 : const Color(0xFFE53935),
          boxShadow: [BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.3),
            blurRadius: _isSending ? 0 : 40,
            spreadRadius: _isSending ? 0 : 10,
          )],
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 8),
        ),
        child: Center(
          child: _isSending
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
                  SizedBox(height: 8),
                  Text('HELP', style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                ]),
        ),
      ),
    );
  }
}
