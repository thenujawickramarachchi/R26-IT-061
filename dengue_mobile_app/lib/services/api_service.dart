import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Real Android phone same WiFi backend URL
  // Backend running on laptop:
  // http://10.170.250.85:5000
  static const String baseUrl = 'http://10.0.2.2:5000';

  // Chrome / Windows run use this:
  // static const String baseUrl = 'http://127.0.0.1:5000';

  // Android Emulator use this:
  // static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<Map<String, dynamic>> getRecommendation({
    required String area,
    required int cases,
    required double rainfall,
    required double temperature,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/recommend');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'area': area,
          'cases': cases,
          'rainfall': rainfall,
          'temperature': temperature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to get recommendation. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Cannot connect to backend. Please check WiFi, backend server, and API URL. Error: $e',
      );
    }
  }

  static Future<Map<String, dynamic>> sendWarning({
    required String area,
    required int cases,
    required double rainfall,
    required double temperature,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/send-warning');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'area': area,
          'cases': cases,
          'rainfall': rainfall,
          'temperature': temperature,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Failed to send warning. Status: ${response.statusCode}. Body: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception(
        'Cannot connect to backend. Please check WiFi, backend server, and API URL. Error: $e',
      );
    }
  }
static Future<List<String>> getMohAreas() async {
    try {
      final url = Uri.parse('$baseUrl/moh-areas');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        return List<String>.from(data['areas'] ?? []);
      } else {
        throw Exception(
          'Failed to load MOH areas. Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Cannot load MOH areas from backend. Error: $e');
    }
  }
}
