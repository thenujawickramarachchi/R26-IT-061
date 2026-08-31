import 'package:shared_preferences/shared_preferences.dart';

class BackendConfig {
  BackendConfig._();

  static const String defaultBaseUrl = 'http://127.0.0.1:8000';
  static const String defaultApiKey = '';

  static String baseUrl = defaultBaseUrl;
  static String apiKey = defaultApiKey;

  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('backend_base_url') ?? defaultBaseUrl;
    apiKey = prefs.getString('backend_api_key') ?? defaultApiKey;
  }

  static Future<void> save(String newBaseUrl, String newApiKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String safeUrl = newBaseUrl.trim().isEmpty
        ? defaultBaseUrl
        : newBaseUrl.trim();
    final String safeApiKey = newApiKey.trim();

    baseUrl = safeUrl;
    apiKey = safeApiKey;

    await prefs.setString('backend_base_url', safeUrl);
    await prefs.setString('backend_api_key', safeApiKey);
  }
}
