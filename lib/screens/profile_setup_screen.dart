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



  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Syncing Profile...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Deep Dark Background
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Edit Profile' : 'Complete Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.isEditMode,
        actions: [
          if (!widget.isEditMode)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              tooltip: 'Logout',
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // --- HEADER SECTION ---
            _buildHeader(),
            const SizedBox(height: 32),

            // --- PERSONAL INFO CARD ---
            _buildSectionCard(
              title: 'Personal Information',
              icon: Icons.person_outline,
              color: Colors.blue.shade400,
              children: [
                _buildTextField(_fullNameController, 'Full Legal Name', Icons.badge_outlined),
                const SizedBox(height: 16),
                _buildTextField(_phoneController, 'Contact Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _buildTextField(_nationalityController, 'Nationality', Icons.public_outlined),
              ],
            ),
            const SizedBox(height: 24),

            // --- IDENTIFICATION CARD ---
            _buildSectionCard(
              title: 'Identification Documents',
              icon: Icons.assignment_ind_outlined,
              color: Colors.blueGrey.shade300,
              children: [
                _buildTextField(_documentTypeController, 'Document Type (e.g., Passport)', Icons.description_outlined),
                const SizedBox(height: 16),
                _buildTextField(_passportController, 'Document / ID Number', Icons.numbers_outlined),
              ],
            ),
            const SizedBox(height: 24),

            // --- MEDICAL INFO CARD (HIGH VISIBILITY) ---
            _buildSectionCard(
              title: 'Emergency Medical Data',
              icon: Icons.medical_services_outlined,
              color: Colors.red.shade400,
              isEmergency: true,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedBloodGroup,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  dropdownColor: const Color(0xFF2C2C2C),
                  decoration: _inputDecoration('Blood Group', Icons.bloodtype_outlined, isEmergency: true),
                  items: _bloodGroups.map((group) {
                    return DropdownMenuItem(value: group, child: Text(group));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBloodGroup = val),
                  iconEnabledColor: Colors.red.shade400,
                ),
                const SizedBox(height: 16),
                _buildTextField(_allergiesController, 'Allergies', Icons.warning_amber_rounded, isEmergency: true, maxLines: 2),
                const SizedBox(height: 16),
                _buildTextField(_medicalConditionsController, 'Medical Conditions', Icons.health_and_safety_outlined, isEmergency: true, maxLines: 2),
              ],
            ),
            const SizedBox(height: 48),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isEditMode ? Colors.white : Colors.blue.shade600,
                  foregroundColor: widget.isEditMode ? Colors.black : Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black45,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  widget.isEditMode ? 'UPDATE ACCOUNT' : 'SAVE & SECURE PROFILE',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.shade400.withOpacity(0.5), width: 2),
          ),
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade900.withOpacity(0.3),
            child: Icon(Icons.person, size: 45, color: Colors.blue.shade400),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<String?>(
          future: _session.getEmail(),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? 'User Account',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            );
          },
        ),
        const Text(
          'Ensure your details are accurate for emergency help.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
    bool isEmergency = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark Card Background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Divider(indent: 20, endIndent: 20, color: Colors.white.withOpacity(0.05)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isEmergency = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: Colors.white), // Visible white text
      decoration: _inputDecoration(label, icon, isEmergency: isEmergency),
      cursorColor: isEmergency ? Colors.red.shade400 : Colors.blue.shade400,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool isEmergency = false}) {
    final activeColor = isEmergency ? Colors.red.shade400 : Colors.blue.shade400;
    
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
      prefixIconColor: WidgetStateColor.resolveWith((states) => 
        states.contains(WidgetState.focused) ? activeColor : Colors.grey.shade600
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: activeColor, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFF2C2C2C), // Dark Field Background
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
