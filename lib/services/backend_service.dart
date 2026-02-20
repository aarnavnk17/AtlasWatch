import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Helper to find a reachable backend URL and perform requests with fallbacks.
/// Automatically detects and connects to backend across all device types.

class BackendService {
  static const Duration _httpTimeout = Duration(seconds: 3);
  static String? _workingBaseUrl;

  /// Comprehensive list of backend candidates to try, in priority order.
  /// Works across Android emulators, iOS simulators, physical devices, and web.
  static List<String> get _candidates {
    final List<String> list = [];

    if (kIsWeb) {
      list.add('http://localhost:3000');
      return list;
    }

    // Android Emulator - tries standard loopback first
    if (Platform.isAndroid) {
      list.addAll([
        'http://10.0.2.2:3000', // Android emulator → host machine
        'http://10.0.2.2:8000',
        'http://10.0.2.2:5000',
      ]);
    }

    // iOS Simulator
    if (Platform.isIOS) {
      list.addAll([
        'http://localhost:3000', // iOS simulator → localhost
        'http://127.0.0.1:3000',
      ]);
    }

    // Physical device - tries common local IPs (192.168.x.x, 10.x.x.x ranges)
    // These cover most home/office networks
    list.addAll([
      'http://192.168.1.1:3000',
      'http://192.168.1.5:3000',
      'http://192.168.1.100:3000',
      'http://192.168.0.1:3000',
      'http://10.0.0.1:3000',
      'http://10.0.0.100:3000',
      'http://172.20.10.1:3000', // Common for some networks
      'http://127.0.0.1:3000',
      'http://localhost:3000',
    ]);

    return list;
  }

  /// Automatically finds a working backend URL by testing connectivity.
  /// Caches the result for future requests.
  static Future<String> _findWorkingBase() async {
    if (_workingBaseUrl != null) return _workingBaseUrl!;

    // Try each candidate URL
    for (final candidate in _candidates) {
      try {
        final uri = Uri.parse('$candidate/');
        final response = await http.get(uri).timeout(_httpTimeout);

        // Success - any response means connection works
        _workingBaseUrl = candidate;
        debugPrint('✓ Backend found at: $candidate');
        return _workingBaseUrl!;
      } catch (_) {
        // Connection failed, try next candidate
        debugPrint('✗ Backend not at: $candidate');
      }
    }

    // If nothing works, log a warning and use localhost as fallback
    debugPrint(
      '⚠ Warning: Could not find working backend. Using http://localhost:3000 as fallback.',
    );
    _workingBaseUrl = 'http://localhost:3000';
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
