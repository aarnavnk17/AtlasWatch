import 'dart:convert';
import 'backend_service.dart';

class CrimeService {
  Future<int> fetchCrimeScore(String area) async {
    try {
      final response = await BackendService.get(
        '/crime-stats?area=${area.toLowerCase()}',
      );
      return _processResponse(response);
    } catch (e) {
      return 0;
    }
  }

  Future<int> fetchCrimeScoreByLocation(double lat, double lng) async {
    try {
      final response = await BackendService.get(
        '/crime-stats/proximity?lat=$lat&lng=$lng&distance=20000', // Increased to 20km
      );
      
      if (response.statusCode != 200) return 0;
      final data = json.decode(response.body);
      
      if (data['success'] == true && (data['data'] as List).isNotEmpty) {
        final closest = data['data'][0];
        final score = closest['score'] ?? 0;
        print('📍 Proximity Match: ${closest['city']} | Score: $score');
        return score;
      }
      return 0;
    } catch (e) {
      print('❌ Proximity Fetch Error: $e');
      return 0;
    }
  }

  int _processResponse(dynamic response) {
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        final score = data['score'] ?? 0;
        print('🏙️ Name-based Match Score: $score');
        return score;
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }
}
