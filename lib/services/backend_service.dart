import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Helper to find a reachable backend URL and perform requests with fallbacks.

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

  static const Duration _httpTimeout = Duration(seconds: 5);

  static String? _workingBaseUrl;

  static List<String> get _candidates {
    final List<String> list = [];
    if (kIsWeb) {
      list.add('http://localhost:3000');
      return list;
    }

    if (!_useEmulator) {
      list.add('http://$_physicalDeviceIp:3000');
      list.add('http://127.0.0.1:3000');
      return list;
    }

    if (Platform.isAndroid) {
      list.addAll([
        'http://10.0.2.2:3000', // Android emulator
        'http://127.0.0.1:3000',
        'http://localhost:3000',
        'http://$_physicalDeviceIp:3000',
      ]);
    } else {
      list.addAll([
        'http://localhost:3000', // iOS simulator
        'http://127.0.0.1:3000',
        'http://$_physicalDeviceIp:3000',
      ]);
    }

    return list;
  }

  static Future<String> _findWorkingBase() async {
    if (_workingBaseUrl != null) return _workingBaseUrl!;

    for (final candidate in _candidates) {
      try {
        final uri = Uri.parse('$candidate/');
        await http.get(uri).timeout(_httpTimeout);
        // Got a response (even 404) — connection succeeded.
        _workingBaseUrl = candidate;
        return _workingBaseUrl!;
      } catch (_) {
        // ignore and try next
      }
    }

    // Fallback to the original getter value.
    _workingBaseUrl = baseUrl;
    return _workingBaseUrl!;
  }

  static Future<http.Response> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final base = await _findWorkingBase();
    final uri = Uri.parse(base + path);
    return http.get(uri, headers: headers).timeout(_httpTimeout);
  }

  static Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final base = await _findWorkingBase();
    final uri = Uri.parse(base + path);
    return http.post(uri, headers: headers, body: body).timeout(_httpTimeout);
  }

  static Future<http.Response> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final base = await _findWorkingBase();
    final uri = Uri.parse(base + path);
    return http.delete(uri, headers: headers).timeout(_httpTimeout);
  }
}
