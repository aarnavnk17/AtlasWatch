import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;

  const ProfileSetupScreen({super.key, required this.isEditMode});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passportController = TextEditingController();
  final _documentTypeController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _allergiesController = TextEditingController();

  String? _selectedBloodGroup;
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

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
        _fullNameController.text = profile['fullName'] ?? '';
        _phoneController.text = profile['phoneNumber'] ?? '';
        _passportController.text = profile['passport'] ?? '';
        _documentTypeController.text = profile['documentType'] ?? '';
        _nationalityController.text = profile['nationality'] ?? '';
        _medicalConditionsController.text = profile['medicalConditions'] ?? '';
        _allergiesController.text = profile['allergies'] ?? '';
        _selectedBloodGroup = profile['bloodGroup'];
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
    setState(() => _loading = true);
    final success = await _session.saveProfile(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      passport: _passportController.text.trim(),
      documentType: _documentTypeController.text.trim(),
      nationality: _nationalityController.text.trim(),
      bloodGroup: _selectedBloodGroup,
      medicalConditions: _medicalConditionsController.text.trim(),
      allergies: _allergiesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save profile')));
      }
    }
  }

  Future<void> _logout() async {
    await _session.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Profile' : 'Profile Setup'),
        automaticallyImplyLeading: widget.isEditMode,
        actions: [
          if (!widget.isEditMode)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fullNameController,
              decoration: _inputDecoration('Full Name', Icons.person),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Phone Number', Icons.phone),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nationalityController,
              decoration: _inputDecoration('Nationality', Icons.flag),
            ),
            const SizedBox(height: 32),
            const Text(
              'Identification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _documentTypeController,
              decoration: _inputDecoration('Document Type (e.g. Passport)', Icons.badge),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passportController,
              decoration: _inputDecoration('Document Number', Icons.numbers),
            ),
            const SizedBox(height: 32),
            const Text(
              'Medical Info (Emergency Use)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              decoration: _inputDecoration('Blood Group', Icons.bloodtype),
              items: _bloodGroups.map((group) {
                return DropdownMenuItem(value: group, child: Text(group));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBloodGroup = val),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _allergiesController,
              decoration: _inputDecoration('Allergies', Icons.warning_amber),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _medicalConditionsController,
              decoration: _inputDecoration('Chronic Medical Conditions', Icons.medical_services),
              maxLines: 2,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.isEditMode ? 'UPDATE PROFILE' : 'SAVE & CONTINUE',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
