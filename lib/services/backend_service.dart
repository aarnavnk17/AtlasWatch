import 'dart:io';
import 'package:flutter/foundation.dart';

class BackendService {
  /// Toggle this to [false] when running on a physical phone.
  /// When [true], it uses 10.0.2.2 for Android emulators and localhost for iOS simulators.
  static const bool _useEmulator = true;

  /// Replace this with your computer's local IP (e.g., 192.168.1.5) 
  /// Find it by running 'ipconfig' (Windows) or 'ifconfig' (Mac) in your terminal.
  static const String _physicalDeviceIp = '172.20.10.2'; 

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    
    if (!_useEmulator) {
      return 'http://$_physicalDeviceIp:3000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Standard Android Emulator loopback
    } else {
      return 'http://localhost:3000'; // iOS Simulator
    }
  }
}
