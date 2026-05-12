import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Backend URL
  static const String baseUrl = "http://10.0.2.2:5000";

  // ===========================
  // 📊 Dashboard Summary
  // ===========================
  static Future<Map<String, dynamic>> dashboard() async {
    final res = await http.get(
      Uri.parse("$baseUrl/dashboard"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("Dashboard API failed");
    }
  }

  // ===========================
  // 📈 Historical Trends
  // ===========================
  static Future<List<dynamic>> history() async {
    final res = await http.get(
      Uri.parse("$baseUrl/history"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["weekly"];
    } else {
      throw Exception("History API failed");
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
  // 📍 MOH Risk Map
  // ===========================
  static Future<List<dynamic>> mohRisk() async {
    final res = await http.get(
      Uri.parse("$baseUrl/moh-risk-map"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["areas"];
    } else {
      throw Exception("Map API failed");
    }
  }

  // ===========================
  // 🔔 Notifications
  // ===========================
  static Future<List<dynamic>> notifications() async {
    final res = await http.get(
      Uri.parse("$baseUrl/notifications"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["notifications"];
    } else {
      throw Exception("Notifications API failed");
    }
  }

  // ===========================
  // 🔥 SHAP GLOBAL EXPLANATION
  // ===========================
  static Future<List<dynamic>> shapGlobal() async {
    final res = await http.get(
      Uri.parse("$baseUrl/xai/shap/global"),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body)["features"];
    } else {
      throw Exception("SHAP Global API failed");
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
  // 🔥 LOCAL SHAP EXPLANATION
  // ===========================
  static Future<Map<String, dynamic>> shapLocal(
    Map<String, dynamic> data,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/xai/shap/local"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(data),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception("SHAP Local API failed");
    }
  }
}