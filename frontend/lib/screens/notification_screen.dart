import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool loading = true;
  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final res = await ApiService.notifications();
      setState(() {
        notifications = res;
        loading = false;
      });
    } catch (e) {
      setState(() {
        notifications = [];
        loading = false;
      });
    }
  }

  IconData iconFor(String type) {
    if (type == "alert") return Icons.warning_amber_rounded;
    if (type == "weather") return Icons.cloud;
    if (type == "insight") return Icons.psychology;
    if (type == "tips") return Icons.lightbulb;
    return Icons.info;
  }

  Color colorFor(String type) {
    if (type == "alert") return const Color(0xFFFF5A4E);
    if (type == "weather") return const Color(0xFF3A9BFF);
    if (type == "insight") return const Color(0xFF9C4DFF);
    if (type == "tips") return const Color(0xFF56B95B);
    return const Color(0xFF5B4BFF);
  }

  String priorityFor(String type) {
    if (type == "alert") return "HIGH";
    if (type == "weather") return "WEATHER";
    if (type == "insight") return "XAI";
    if (type == "tips") return "INFO";
    return "NOTICE";
  }

  Widget notificationCard(Map<String, dynamic> n) {
    final type = n["type"]?.toString() ?? "info";
    final color = colorFor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: type == "alert"
              ? color.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconFor(type),
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n["title"]?.toString() ?? "Notification",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172033),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        priorityFor(type),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  n["body"]?.toString() ?? "",
                  style: const TextStyle(
                    color: Color(0xFF5F6B7A),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  n["time"]?.toString() ?? "",
                  style: const TextStyle(
                    color: Color(0xFF98A1B2),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
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
        body: Center(child: CircularProgressIndicator()),
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
        child: notifications.isEmpty
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                children: notifications.map<Widget>((n) {
                  return notificationCard(
                    Map<String, dynamic>.from(n as Map),
                  );
                }).toList(),
              ),
      ),
    );
  }
}