import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WarningHistoryScreen extends StatefulWidget {
  const WarningHistoryScreen({super.key});

  @override
  State<WarningHistoryScreen> createState() => _WarningHistoryScreenState();
}

class _WarningHistoryScreenState extends State<WarningHistoryScreen> {
  List<Map<String, dynamic>> warnings = [];
  bool isLoading = true;
  String? errorMessage;

  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);

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
    if (risk == 'HIGH') return Colors.red;
    if (risk == 'MEDIUM') return Colors.orange;
    return Colors.green;
  }

  String formatDate(String value) {
    final date = DateTime.tryParse(value);

    if (date == null) return value;

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Warning History'),
        actions: [
          IconButton(
            onPressed: isLoading ? null : loadWarningHistory,
            icon: const Icon(Icons.refresh_rounded),
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
            icon: Icons.error_outline_rounded,
            color: Colors.red,
            message: errorMessage!,
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
        padding: const EdgeInsets.all(18),
        children: [
          messageCard(
            icon: Icons.history_toggle_off_rounded,
            color: Colors.blueGrey,
            message: 'No warning records have been saved yet.',
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
              '${warnings.length} recent PHI warning records',
              style: const TextStyle(color: sub),
            ),
          );
        }

        return warningCard(warnings[index - 1]);
      },
    );
  }

  Widget warningCard(Map<String, dynamic> item) {
    final risk = (item['risk_level'] ?? 'UNKNOWN').toString();
    final emailSent = item['email_sent'] == true;

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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                badge(risk, riskColor(risk)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatDate(item['created_at']?.toString() ?? ''),
              style: const TextStyle(color: sub, fontSize: 12),
            ),
            const Divider(height: 24),
            detailRow(
              Icons.bug_report_rounded,
              'Cases',
              '${item['dengue_cases'] ?? '-'}',
            ),
            detailRow(
              Icons.water_drop_rounded,
              'Rainfall',
              '${item['rainfall_mm'] ?? '-'} mm',
            ),
            detailRow(
              Icons.thermostat_rounded,
              'Temperature',
              '${item['temperature_c'] ?? '-'} °C',
            ),
            detailRow(
              Icons.recommend_rounded,
              'Action',
              item['recommended_action']?.toString() ?? '-',
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (emailSent ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    emailSent
                        ? Icons.mark_email_read_rounded
                        : Icons.error_outline_rounded,
                    color: emailSent ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emailSent
                          ? 'Email sent to ${item['recipient_email'] ?? 'PHI officer'}'
                          : (item['email_message']?.toString() ??
                              'Email was not sent'),
                      style: TextStyle(
                        color: emailSent
                            ? Colors.green.shade800
                            : Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
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
          Icon(icon, size: 18, color: Colors.redAccent),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: sub)),
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
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
              style: const TextStyle(color: title),
            ),
          ),
        ],
      ),
    );
  }
}