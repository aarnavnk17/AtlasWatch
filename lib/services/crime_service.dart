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
        '/crime-stats/proximity?lat=$lat&lng=$lng&distance=5000', // 5km radius
      );
      
      if (response.statusCode != 200) return 0;
      final data = json.decode(response.body);
      
      if (data['success'] == true && (data['data'] as List).isNotEmpty) {
        // Use the closest matching crime zone
        final closest = data['data'][0];
        return (closest['score'] ?? 0);
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  int _processResponse(dynamic response) {
    if (response.statusCode != 200) return 0;
    final data = json.decode(response.body);

    final theft = data['theft'] ?? 0;
    final assault = data['assault'] ?? 0;
    final fraud = data['fraud'] ?? 0;

    // Weighted scoring model
    return theft + (assault * 2) + fraud;
  }
}
