import 'package:flutter/material.dart';
import 'services/session_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/sos_screen.dart';
import 'theme/app_theme.dart';
import 'services/location_tracking_service.dart';

// Global navigator key — lets background tracking push SOS from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start background location tracking (5-min intervals)
  // If AI detects critical danger, auto-launches SOS from anywhere in the app
  LocationTrackingService().startTracking();

  runApp(const AtlasWatchApp());
}

class AtlasWatchApp extends StatelessWidget {
  const AtlasWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const EntryGate(),
    );
  }
}

class EntryGate extends StatelessWidget {
  const EntryGate({super.key});

  Future<Widget> _decideStartScreen() async {
    final session = SessionService();
    try {
      final loggedIn = await session.isLoggedIn();
      if (!loggedIn) return const LoginScreen();
      final profileComplete = await session.isProfileComplete();
      if (!profileComplete) return const ProfileSetupScreen(isEditMode: false);
      return const DashboardScreen();
    } catch (e) {
      debugPrint('EntryGate Error: $e');
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _decideStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('An error occurred during startup'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => (context as Element).markNeedsBuild(),
                child: const Text('Retry'),
              ),
            ],
          )));
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snapshot.data!;
      },
    );
  }
}
