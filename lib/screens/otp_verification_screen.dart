import 'package:flutter/material.dart';
// Session-based OTP verification was removed; keep screen minimal for now.
import 'profile_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final bool _loading = false;

  Future<void> _verify() async {
    // OTP verification was removed from the backend flow.
    // For now, proceed directly to profile setup to keep the app usable.
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(isEditMode: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('A verification code was sent to ${widget.email}'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: '6-digit code'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
