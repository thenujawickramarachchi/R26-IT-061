import 'package:flutter/material.dart';

import '../services/api_service.dart';

class WarningHistoryScreen extends StatefulWidget {
  const WarningHistoryScreen({super.key});

  @override
  State<WarningHistoryScreen> createState() => _WarningHistoryScreenState();
}

class _WarningHistoryScreenState extends State<WarningHistoryScreen> {
  static const Color bg = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color title = Color(0xFF172033);
  static const Color sub = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);

  static const Color navy = Color(0xFF12355B);
  static const Color blue = Color(0xFF2563EB);
  static const Color teal = Color(0xFF007C83);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color success = Color(0xFF15803D);

  List<Map<String, dynamic>> warnings = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadWarningHistory();
  }

  Future<void> loadWarningHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final records = await ApiService.getWarningHistory(limit: 20);

      if (!mounted) return;

      setState(() {
        warnings = records;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Color riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return danger;
      case 'MEDIUM':
        return warning;
      case 'LOW':
        return success;
      default:
        return blue;
    }
  }

  String formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();

    if (date == null) return value.isEmpty ? 'Not available' : value;

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  bool isEmailSent(Map<String, dynamic> item) {
    final value = item['email_sent'];
    return value == true || '$value'.toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Alert History'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadWarningHistory,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadWarningHistory,
        child: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          messageCard(
            icon: Icons.cloud_off_outlined,
            color: blue,
            message:
                'Could not load advisory history. Check the backend connection and try again.',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: loadWarningHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('TRY AGAIN'),
          ),
        ],
      );
    }

    if (warnings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          messageCard(
            icon: Icons.history_toggle_off_rounded,
            color: blue,
            message: 'No advisory records have been saved yet.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      itemCount: warnings.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${warnings.length} recent PHI advisory records',
              style: const TextStyle(
                color: sub,
                fontSize: 13,
              ),
            ),
          );
        }

        return warningCard(warnings[index - 1]);
      },
    );
  }

  Widget warningCard(Map<String, dynamic> item) {
    final risk = (item['risk_level'] ?? 'UNKNOWN').toString();
    final emailSent = isEmailSent(item);
    final statusColor = emailSent ? success : warning;

    return Card(
      color: card,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['moh_area_name']?.toString() ?? 'Unknown area',
                    style: const TextStyle(
                      color: title,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                badge(risk, riskColor(risk)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatDate(item['created_at']?.toString() ?? ''),
              style: const TextStyle(
                color: sub,
                fontSize: 12,
              ),
            ),
            const Divider(height: 24),
            detailRow(
              Icons.bug_report_outlined,
              'Cases',
              '${item['dengue_cases'] ?? '-'}',
            ),
            detailRow(
              Icons.water_drop_outlined,
              'Rainfall',
              '${item['rainfall_mm'] ?? '-'} mm',
            ),
            detailRow(
              Icons.thermostat_outlined,
              'Temperature',
              '${item['temperature_c'] ?? '-'} °C',
            ),
            detailRow(
              Icons.task_alt_outlined,
              'Action',
              item['recommended_action']?.toString() ?? '-',
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(
                    emailSent
                        ? Icons.mark_email_read_outlined
                        : Icons.schedule_send_outlined,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emailSent
                          ? 'Email sent to ${item['recipient_email'] ?? 'PHI officer'}'
                          : (item['email_message']?.toString() ??
                              'Advisory saved; email delivery is pending.'),
                      style: TextStyle(
                        color: emailSent ? success : warning,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: blue),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: sub),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: title),
            ),
          ),
        ],
      ),
    );
  }

  Widget badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget messageCard({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: title,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}