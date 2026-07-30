import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator:
static const String baseUrl = "http://10.206.234.147:8000";
  // static const String baseUrl = "http://127.0.0.1:8000";

  static Future<Map<String, dynamic>> sendMessageAdvanced(String message) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return _error("Backend connection failed: $e");
    }

    return _error("Error connecting to server");
  }

  static Future<Map<String, dynamic>> checkMisinformation(String claim) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/check-misinformation"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"claim": claim}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {
        "status": "Error",
        "confidence": 0.0,
        "explanation": "Could not connect to backend: $e",
        "recommendation": "Check backend server."
      };
    }

    return {
      "status": "Error",
      "confidence": 0.0,
      "explanation": "Could not connect to backend.",
      "recommendation": "Check backend server."
    };
  }

  static Future<Map<String, dynamic>> uploadReportBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload-report"),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {
        "message": "Upload failed",
        "analysis": {
          "summary": "Could not analyze report: $e",
          "risk_level": "Unknown",
          "keywords": {}
        }
      };
    }

    return {
      "message": "Upload failed",
      "analysis": {
        "summary": "Could not analyze report.",
        "risk_level": "Unknown",
        "keywords": {}
      }
    };
  }

  static Future<Map<String, dynamic>> simulateRisk(Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/simulate-risk"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {
        "error": true,
        "message": "Simulator connection failed: $e",
      };
    }

    return {
      "error": true,
      "message": "Simulator request failed",
    };
  }

  static Map<String, dynamic> _error(String message) {
    return {
      "response": message,
      "confidence": 0.0,
      "why_this_answer": "The backend did not return a valid response.",
      "temporal_insight": "No temporal insight available.",
      "locations": [],
      "misinformation": {
        "status": "Unknown",
        "confidence": 0.0,
        "explanation": "",
        "recommendation": ""
      },
      "evidence": []
    };
  }
}
