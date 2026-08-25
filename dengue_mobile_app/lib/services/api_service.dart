import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Hosted model API used only for the area proxy-risk preview.
  // Keep recommendation, PHI warning, and database calls on baseUrl until
  // their hosted versions are fully tested.
  static const String areaRiskBaseUrl =
      'https://sahan-kaveesha-r26-it-061-dengue-api.hf.space';

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

  static Future<List<Map<String, dynamic>>> getWarningHistory({
    int limit = 20,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/warning-history?limit=$limit');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final warnings = data['warnings'] as List? ?? [];

        return warnings
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }

      throw Exception(
        'Failed to load warning history. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot load warning history. Error: $e');
    }
  }

  static Future<List<String>> getMohAreas() async {
    try {
      final url = Uri.parse('$baseUrl/moh-areas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['areas'] ?? []);
      }

      throw Exception(
        'Failed to load MOH areas. Status: ${response.statusCode}',
      );
    } catch (e) {
      throw Exception('Cannot load MOH areas from backend. Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAreaProxyRisk({
    required String area,
    required int year,
    required int week,
  }) async {
    try {
      final url = Uri.parse('$areaRiskBaseUrl/predict-area-risk');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'area': area,
          'year': year,
          'week': week,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception(
        'Area risk preview unavailable. Status: ${response.statusCode}.',
      );
    } catch (e) {
      throw Exception('Cannot load area risk preview. Error: $e');
    }
  }
    static Future<Map<String, dynamic>> submitFeedback({
    required int warningHistoryId,
    required int casesAfter,
    required int followUpDays,
    required String outcomeStatus,
    String feedbackNotes = '',
  }) async {
    try {
      final url = Uri.parse('$baseUrl/submit-feedback');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'warning_history_id': warningHistoryId,
          'cases_after': casesAfter,
          'follow_up_days': followUpDays,
          'outcome_status': outcomeStatus,
          'feedback_notes': feedbackNotes,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception(
        'Failed to submit feedback. '
        'Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot submit intervention feedback. Error: $e');
    }
  }
}
