import 'package:flutter/material.dart';
import '../services/xai_api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool loading = true;
  String? errorMessage;

  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final res = await ApiService.notifications();

      final loadedNotifications = res
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .where((item) {
        final riskLevel = item["risk_level"]?.toString().toUpperCase() ?? "";

        return riskLevel == "HIGH" || riskLevel == "MEDIUM";
      }).toList();

      if (!mounted) return;

      setState(() {
        notifications = loadedNotifications;
        loading = false;
      });

      debugPrint("========== NOTIFICATIONS API RESPONSE ==========");
      debugPrint(loadedNotifications.toString());
      debugPrint(
          "First notification: ${loadedNotifications.isNotEmpty ? loadedNotifications.first : "No notifications"}");
      debugPrint("Total notifications: ${loadedNotifications.length}");
      debugPrint("===============================================");
    } catch (e) {
      debugPrint("Notification API error: $e");

      if (!mounted) return;

      setState(() {
        notifications = [];
        errorMessage = e.toString();
        loading = false;
      });
    }
  }

  IconData iconFor(String type) {
    switch (type.toLowerCase()) {
      case "alert":
      case "high":
        return Icons.warning_amber_rounded;

      case "weather":
        return Icons.cloud_rounded;

      case "insight":
      case "xai":
        return Icons.psychology_rounded;

      case "tips":
      case "tip":
        return Icons.lightbulb_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color colorFor(String type) {
    switch (type.toLowerCase()) {
      case "alert":
      case "high":
        return const Color(0xFFFF477E);

      case "weather":
        return const Color(0xFF3A9BFF);

      case "insight":
      case "xai":
        return const Color(0xFF8B5CF6);

      case "tips":
      case "tip":
        return const Color(0xFF18A982);

      default:
        return const Color(0xFF5B4BFF);
    }
  }

  String priorityFor(Map<String, dynamic> notification) {
    final type = notification["type"]?.toString().toLowerCase() ?? "notice";

    final priority = notification["priority"]?.toString();

    if (priority != null && priority.isNotEmpty) {
      return priority.toUpperCase();
    }

    switch (type) {
      case "alert":
      case "high":
        return "HIGH";

      case "weather":
        return "WEATHER";

      case "insight":
      case "xai":
        return "XAI";

      case "tips":
      case "tip":
        return "INFO";

      default:
        return "NOTICE";
    }
  }

  Widget notificationCard(Map<String, dynamic> n) {
    final risk = n["risk_level"]?.toString().toUpperCase() ?? "";

    final area = n["moh_area_name"]?.toString() ??
        n["area"]?.toString() ??
        "Unknown Area";

    final dengueCases = n["dengue_cases"]?.toString() ?? "0";
    final rainfall = n["rainfall_mm"]?.toString() ?? "0";
    final temperature = n["temperature_c"]?.toString() ?? "0";
    final recommendedAction =
        n["recommended_action"]?.toString() ?? "No action available";

    final rawTime = n["created_at"]?.toString() ?? "";
    String time = rawTime;

    if (rawTime.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(rawTime).toLocal();

        time =
            "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}  "
            "${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        time = rawTime;
      }
    }

    final isHigh = risk == "HIGH";

    final riskColor =
        isHigh ? const Color(0xFFFF477E) : const Color(0xFF5B4BFF);

    final lightRiskColor =
        isHigh ? const Color(0xFFFFEEF3) : const Color(0xFFF1EFFF);

    final icon =
        isHigh ? Icons.warning_amber_rounded : Icons.notifications_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===========================
          // HEADER
          // ===========================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: lightRiskColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: riskColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "Dengue Risk Alert",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: lightRiskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk,
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===========================
          // MOH AREA
          // ===========================
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 17,
                color: riskColor,
              ),
              const SizedBox(width: 6),
              Text(
                area,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===========================
          // DATA BOXES
          // ===========================
          Row(
            children: [
              Expanded(
                child: alertMetric(
                  icon: Icons.coronavirus_rounded,
                  label: "Cases",
                  value: dengueCases,
                  color: riskColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: alertMetric(
                  icon: Icons.water_drop_rounded,
                  label: "Rainfall",
                  value: "$rainfall mm",
                  color: const Color(0xFF3A9BFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: alertMetric(
                  icon: Icons.thermostat_rounded,
                  label: "Temp",
                  value: "$temperature°C",
                  color: const Color(0xFFFF8A3D),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ===========================
          // RECOMMENDED ACTION
          // ===========================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: lightRiskColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  color: riskColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Recommended Action",
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        recommendedAction,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // ===========================
          // TIME
          // ===========================
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 15,
                color: Color(0xFF8A94A6),
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(
                  color: Color(0xFF8A94A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget alertMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE7ECF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A94A6),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9FD),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9FD),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Color(0xFF5B4BFF),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Notifications",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Live dengue alert center",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDF2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${notifications.length} Alerts",
                style: const TextStyle(
                  color: Color(0xFFFF2F6D),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: errorMessage != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 70,
                    color: Color(0xFFFF477E),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text(
                      "Unable to load notifications",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5F6B7A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: loadNotifications,
                      child: const Text("Try Again"),
                    ),
                  ),
                ],
              )
            : notifications.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 120),
                      Icon(
                        Icons.notifications_off,
                        size: 70,
                        color: Color(0xFF98A1B2),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          "No alerts available",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5F6B7A),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      12,
                      18,
                      100,
                    ),
                    children:
                        notifications.map<Widget>(notificationCard).toList(),
                  ),
      ),
    );
  }
}
