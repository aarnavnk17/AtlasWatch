import 'dart:io';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('My Identity', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // --- AVATAR SECTION ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade400.withOpacity(0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFF1E1E1E),
                    backgroundImage: UserProfile.photoPath != null
                        ? FileImage(File(UserProfile.photoPath!))
                        : null,
                    child: UserProfile.photoPath == null
                        ? Icon(Icons.person_rounded, size: 50, color: Colors.blue.shade400)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verified Identity',
                style: TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),

              const SizedBox(height: 48),

              // --- PROFILE DATA ---
              _infoTile('Document Type', UserProfile.documentType, Icons.description_outlined),
              _infoTile('Document Number', UserProfile.documentNumber, Icons.badge_outlined),
              _infoTile('Nationality', UserProfile.nationality, Icons.public_outlined),

              const Spacer(),

              // --- LOGOUT ACTION ---
              SizedBox(
                width: double.infinity,
                height: 60,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    backgroundColor: Colors.red.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 22),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? 'Not Provided' : value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
