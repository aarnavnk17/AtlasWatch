import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../models/risk_level.dart';
import '../services/session_service.dart';
import '../services/location_service.dart';
import '../services/crime_service.dart';
import '../services/risk_service.dart';
import '../widgets/sleek_animation.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'journey_details_screen.dart';
import 'sos_screen.dart';
import 'contact_manager_screen.dart';
import 'document_vault_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SessionService _session = SessionService();
  RiskLevel _riskLevel = RiskLevel.low;
  String? _locationName;
  String _userName = "User";
  bool _loadingLocation = true;
  LatLng _currentLatLng = const LatLng(0, 0);
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchLocationAndRisk();
  }

  Future<void> _fetchUserData() async {
    final profile = await _session.loadProfile();
    final email = await _session.getEmail();
    
    String displayName = "User";
    
    // 1. Try fullName from profile
    if (profile != null && profile['fullName'] != null && profile['fullName'].toString().trim().isNotEmpty) {
      displayName = profile['fullName'];
    } 
    // 2. Fallback to Email Prefix (e.g. 'aarnav' from 'aarnav@example.com')
    else if (email != null && email.contains('@')) {
      displayName = email.split('@')[0];
      // Capitalize first letter
      displayName = displayName[0].toUpperCase() + displayName.substring(1);
    }

    if (mounted) {
      setState(() {
        _userName = displayName;
      });
    }
  }

  Future<void> _simulateLocation(String customLocation) async {
    if (customLocation.isEmpty) return;

    setState(() {
      _loadingLocation = true;
      _locationName = customLocation;
    });

    try {
      List<Location> locations = await locationFromAddress(customLocation);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final newLatLng = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _currentLatLng = newLatLng;
        });
      }
    } catch (e) {
      debugPrint('Error geocoding custom location: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not find location: $customLocation')),
      );
    }

    final crimeService = CrimeService();
    final riskService = RiskService();
    final score = await crimeService.fetchCrimeScore(customLocation);

    if (!mounted) return;

    setState(() {
      _riskLevel = riskService.calculateRisk(score);
      _loadingLocation = false;
    });
  }

  Future<void> _fetchLocationAndRisk() async {
    final locationService = LocationService();
    try {
      final result = await locationService.fetchCurrentLocation();

      if (!mounted) return;

      if (result != null) {
        final newLatLng = LatLng(result.position.latitude, result.position.longitude);
        setState(() {
          _loadingLocation = false;
          _currentLatLng = newLatLng;
          _locationName = result.address;
        });

        if (result.address != null) {
          final crimeService = CrimeService();
          final riskService = RiskService();
          final score = await crimeService.fetchCrimeScore(result.address!);

          if (!mounted) return;

          setState(() {
            _riskLevel = riskService.calculateRisk(score);
          });
        }
      } else {
        setState(() {
          _loadingLocation = false;
          _locationName = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      if (mounted) {
        setState(() {
          _loadingLocation = false;
          _locationName = 'Location unavailable';
        });
      }
    }
  }

  Color get _riskColor {
    switch (_riskLevel) {
      case RiskLevel.low:
        return const Color(0xFF4CAF50);
      case RiskLevel.medium:
        return const Color(0xFFFF9800);
      case RiskLevel.high:
        return const Color(0xFFE53935);
    }
  }

  String get _riskLabel {
    switch (_riskLevel) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
    }
  }

  Future<void> _logout() async {
    await _session.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              SleekAnimation(
                type: SleekAnimationType.fade,
                delay: const Duration(milliseconds: 100),
                child: _buildHeader(),
              ),
              const SizedBox(height: 32),

              // --- RISK & LOCATION HERO CARD ---
              SleekAnimation(
                type: SleekAnimationType.slide,
                slideOffset: const Offset(0.05, 0),
                delay: const Duration(milliseconds: 300),
                child: _buildRiskHeroCard(),
              ),
              const SizedBox(height: 24),

              // --- TOOLS GRID ---
              SleekAnimation(
                type: SleekAnimationType.fade,
                delay: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildToolCard(
                        'Vault',
                        Icons.folder_shared_outlined,
                        Colors.blue.shade400,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentVaultScreen())),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildToolCard(
                        'Contacts',
                        Icons.people_alt_outlined,
                        Colors.orange.shade400,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactManagerScreen())),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- START JOURNEY BUTTON ---
              SleekAnimation(
                type: SleekAnimationType.slide,
                slideOffset: const Offset(0, 0.1),
                delay: const Duration(milliseconds: 700),
                child: _buildLargeActionButton(
                  'START JOURNEY',
                  'Activate live safety tracking',
                  Icons.navigation_outlined,
                  Colors.blue.shade600,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JourneyDetailsScreen(riskLevel: _riskLevel)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- SOS BUTTON ---
              SleekAnimation(
                type: SleekAnimationType.slide,
                slideOffset: const Offset(0, 0.1),
                delay: const Duration(milliseconds: 900),
                child: _buildLargeActionButton(
                  'SOS EMERGENCY',
                  'Instant alert to contacts & services',
                  Icons.warning_amber_rounded,
                  const Color(0xFFE53935),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen())),
                  isHighImpact: true,
                ),
              ),

              const SizedBox(height: 32),

              // --- DEV TOOLS ---
              SleekAnimation(
                delay: const Duration(milliseconds: 1100),
                child: _buildDevTools(),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_userName,',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'Stay safe today.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 22),
              tooltip: 'Sign Out',
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen(isEditMode: true))),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF1E1E1E),
                  child: const Icon(Icons.person, color: Colors.blue, size: 28),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(28),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safety Status',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (_loadingLocation)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  onPressed: _fetchLocationAndRisk,
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _riskLabel,
                style: TextStyle(
                  color: _riskColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _riskColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _locationName ?? 'Detecting location...',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _riskLevel == RiskLevel.low ? 0.2 : (_riskLevel == RiskLevel.medium ? 0.5 : 0.9),
              backgroundColor: Colors.white.withOpacity(0.05),
              color: _riskColor,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeActionButton(String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {bool isHighImpact = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isHighImpact ? color : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(24),
          border: isHighImpact ? null : Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighImpact ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isHighImpact ? Colors.white : color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isHighImpact ? Colors.white.withOpacity(0.8) : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isHighImpact ? Colors.white : Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDevTools() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: const Text('Developer Options', style: TextStyle(color: Colors.grey, fontSize: 13)),
        iconColor: Colors.grey,
        collapsedIconColor: Colors.grey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter city (testing)',
                          hintStyle: const TextStyle(color: Colors.grey),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF2C2C2C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _simulateLocation(_locationController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Simulate'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

