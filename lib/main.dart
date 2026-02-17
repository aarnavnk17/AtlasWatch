import 'package:flutter/material.dart';
import 'services/session_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_setup_screen.dart';

import 'services/geofence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Geofencing
  final geofenceService = GeofenceService();
  await geofenceService.initialize();

  runApp(const AtlasWatchApp());
}

class AtlasWatchApp extends StatelessWidget {
  const AtlasWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ FORCE DARK MODE
      themeMode: ThemeMode.dark,

      // Dark theme configuration
      theme: ThemeData.dark(useMaterial3: true),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        cardColor: const Color(0xFF1A1D24),
      ),

      home: const EntryGate(),
    );
  }
}

class EntryGate extends StatelessWidget {
  const EntryGate({super.key});

  Future<Widget> _decideStartScreen() async {
    final session = SessionService();
    final loggedIn = await session.isLoggedIn();

    if (!loggedIn) {
      return const LoginScreen();
    }

    final profileComplete = await session.isProfileComplete();

    if (!profileComplete) {
      return const ProfileSetupScreen(isEditMode: false);
    }

    return const DashboardScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _decideStartScreen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!;
      },
    );
  }
}
