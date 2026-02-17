import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;

  const ProfileSetupScreen({super.key, required this.isEditMode});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _passportController = TextEditingController();
  final _documentTypeController = TextEditingController();
  final _nationalityController = TextEditingController();

  final SessionService _session = SessionService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final profile = await _session.loadProfile();

      if (profile != null) {
        _passportController.text = profile['passport'] ?? '';
        _documentTypeController.text = profile['documentType'] ?? '';
        _nationalityController.text = profile['nationality'] ?? '';
      }
    } catch (e) {
      debugPrint("ProfileSetup Error: $e");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    final success = await _session.saveProfile(
      passport: _passportController.text.trim(),
      documentType: _documentTypeController.text.trim(),
      nationality: _nationalityController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      await _session.setProfileComplete(true);

      if (!mounted) return;

      if (!widget.isEditMode) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated Successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
        automaticallyImplyLeading: widget.isEditMode,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _passportController,
              decoration: const InputDecoration(labelText: 'Passport Number'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _documentTypeController,
              decoration: const InputDecoration(labelText: 'Document Type'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nationalityController,
              decoration: const InputDecoration(labelText: 'Nationality'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
