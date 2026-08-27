import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://sahan-kaveesha-r26-it-061-dengue-api.hf.space';

  static Future<Map<String, dynamic>> getRecommendation({
    required String area,
    required int cases,
    required double rainfall,
    required double temperature,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recommend'),
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
      }

      throw Exception(
        'Failed to get recommendation. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot connect to recommendation service. Error: $e');
    }
  }

  static Future<Map<String, dynamic>> sendWarning({
    required String area,
    required int cases,
    required double rainfall,
    required double temperature,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-warning'),
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
      }

      throw Exception(
        'Failed to send warning. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot send PHI warning. Error: $e');
    }
  }

  static Future<List<String>> getMohAreas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/moh-areas'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['areas'] ?? []);
      }

      throw Exception(
        'Failed to load MOH areas. Status: ${response.statusCode}.',
      );
    } catch (e) {
      throw Exception('Cannot load MOH areas. Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAreaWeather({
    required String area,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/area-weather').replace(
        queryParameters: {'area': area},
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
      }

      throw Exception(
        'Failed to load area weather. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot load area weather. Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getAreaProxyRisk({
    required String area,
    required int year,
    required int week,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict-area-risk'),
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
        'Area risk preview unavailable. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot load area risk preview. Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getWarningHistory({
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/warning-history?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final warnings =
            (data['warning_history'] ?? data['warnings'] ?? []) as List;

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

  static Future<Map<String, dynamic>> submitFeedback({
    required int warningHistoryId,
    required int casesAfter,
    required int followUpDays,
    required String outcomeStatus,
    String feedbackNotes = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit-feedback'),
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
        'Failed to submit feedback. Status: ${response.statusCode}. '
        'Body: ${response.body}',
      );
    } catch (e) {
      throw Exception('Cannot submit intervention feedback. Error: $e');
    }
  }
}