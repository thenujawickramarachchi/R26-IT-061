import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL
  static const String baseUrl =
      "https://sahan-kaveesha-r26-it-061-dengue-api.hf.space";

// ===========================
// 📊 Today's Dashboard
// ===========================
  static Future<Map<String, dynamic>> dashboard() async {
    final res = await http.get(
      Uri.parse("$baseUrl/today-dashboard"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Today's Dashboard API failed");
    }
  }

  // ===========================
// 📈 Historical Trends
// ===========================
  static Future<List<dynamic>> history() async {
    final res = await http.get(
      Uri.parse("$baseUrl/trend/weekly-summary?weeks=12"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      return data["weekly_summary"] ?? [];
    } else {
      throw Exception(
        "Trend API failed: ${res.statusCode} ${res.body}",
      );
    }
  }

  // ===========================
// 📈 REAL MODEL RISK TIMELINE
// ===========================
  static Future<List<dynamic>> riskTimeline() async {
    final res = await http.get(
      Uri.parse("$baseUrl/xai/risk-timeline"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["timeline"];
    } else {
      throw Exception("Risk Timeline API failed");
    }
  }

  // ===========================
// 📍 MOH Areas
// ===========================
  static Future<List<dynamic>> mohRisk() async {
    final res = await http.get(
      Uri.parse("$baseUrl/moh-areas"),
      headers: {
        "Accept": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
        "MOH Areas API failed: "
        "${res.statusCode} ${res.body}",
      );
    }

    final data = jsonDecode(res.body);

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      final areas = data["areas"] ?? data["moh_areas"] ?? data["data"];

      if (areas is List) {
        return areas;
      }
    }

    throw Exception(
      "Invalid MOH Areas API response",
    );
  }

  // ===========================
// 📍 AREA PROXY RISK
// ===========================
  static Future<Map<String, dynamic>> predictAreaRisk({
    required String area,
    required int year,
    required int week,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/predict-area-risk"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "year": year,
        "week": week,
        "area": area,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Area Risk API failed: "
        "${res.statusCode} ${res.body}",
      );
    }
  }

  static Future<List<dynamic>> notifications() async {
    final res = await http.get(
      Uri.parse("$baseUrl/warning-history"),
      headers: {
        "Accept": "application/json",
      },
    );

    print("========== WARNING HISTORY API ==========");
    print("Status Code: ${res.statusCode}");
    print("Response: ${res.body}");
    print("=========================================");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      if (data is List) {
        return data;
      }

      if (data is Map<String, dynamic>) {
        final warnings = data["warnings"] ??
            data["warning_history"] ??
            data["history"] ??
            data["data"];

        if (warnings is List) {
          return warnings;
        }
      }

      throw Exception(
        "Invalid Warning History API response: ${res.body}",
      );
    } else {
      throw Exception(
        "Warning History API failed: "
        "${res.statusCode} ${res.body}",
      );
    }
  }

  // ===========================
// 🌐 GLOBAL SHAP EXPLANATION
// ===========================
  static Future<List<dynamic>> shapGlobal() async {
    final res = await http.get(
      Uri.parse("$baseUrl/shap/global"),
      headers: {
        "Accept": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      return data["global_shap"] ?? [];
    } else {
      throw Exception(
        "SHAP Global API failed: "
        "${res.statusCode} ${res.body}",
      );
    }
  }

  // ===========================
  // 🔥 SAMPLE LATEST WEEK DATA
  // ===========================
  static Future<Map<String, dynamic>> sampleInput() async {
    final res = await http.get(
      Uri.parse("$baseUrl/sample-input"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Sample Input API failed");
    }
  }

  // ===========================
// 🎯 LOCAL SHAP EXPLANATION
// ===========================
  static Future<Map<String, dynamic>> shapLocal(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/shap/local"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception(
        "SHAP Local API failed: "
        "${res.statusCode} ${res.body}",
      );
    }
  }
}
