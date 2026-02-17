import 'dart:convert';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class CrimeService {
  Future<int> fetchCrimeScore(String area) async {
    final uri = Uri.parse(
      '${BackendService.baseUrl}/crime-stats?area=${area.toLowerCase()}',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      return 0;
    }

    final data = json.decode(response.body);

    final theft = data['theft'] ?? 0;
    final assault = data['assault'] ?? 0;
    final fraud = data['fraud'] ?? 0;

    // Weighted scoring model
    return theft + (assault * 2) + fraud;
  }
}
