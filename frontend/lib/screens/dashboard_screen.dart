import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      final res = await ApiService.dashboard();
      setState(() {
        data = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Color riskColor(String risk) {
    if (risk == "High") return const Color(0xFFFF2F6D);
    if (risk == "Medium") return Colors.orange;
    return Colors.green;
  }

  Widget metricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF5B4BFF),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8A94A6),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
              fontSize: 27,
            ),
          ),
        ],
      ),
    );
  }

  Widget riskCard(String risk, double confidence) {
    final color = riskColor(risk);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Current Colombo Risk",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "$risk Risk",
                  style: TextStyle(
                    fontSize: 46,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Confidence: ${(confidence * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                    color: Color(0xFF5F6B7A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF172033),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.monitor_heart,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget statusCard(String risk) {
    final high = risk.toLowerCase() == "high";

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFFF1F4) : const Color(0xFFF4FFF7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: high ? const Color(0xFFFF2F6D) : Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  high
                      ? "Elevated Dengue Risk Detected"
                      : "Dengue Situation Stable",
                  style: TextStyle(
                    color: high ? const Color(0xFFB3194A) : Colors.green,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  high
                      ? "The trained dengue prediction model indicates elevated outbreak probability within Colombo district. Preventive surveillance and environmental monitoring are recommended."
                      : "Current dengue-climate indicators remain within moderate outbreak thresholds.",
                  style: const TextStyle(
                    color: Color(0xFF5F6B7A),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
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
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final risk = data?["risk_level"] ?? "Unknown";
    final current = data?["current"] ?? {};
    final confidence = ((data?["confidence"] ?? 0) as num).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.health_and_safety,
                color: Color(0xFFFF2F6D),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dengue Dashboard",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Colombo District Monitoring",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            riskCard(risk, confidence)
                .animate()
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms),

            const SizedBox(height: 18),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              childAspectRatio: 1.1,
              children: [
                metricCard(
                  icon: Icons.coronavirus,
                  title: "MOH CASES",
                  value: "${current["cases"] ?? "-"}",
                ),
                metricCard(
                  icon: Icons.air,
                  title: "WIND SPEED",
                  value: "${current["wind_speed_kmh"] ?? "-"} km/h",
                ),
                metricCard(
                  icon: Icons.thermostat,
                  title: "TEMPERATURE",
                  value: "${current["temp_mean_c"] ?? "-"} °C",
                ),
                metricCard(
                  icon: Icons.opacity,
                  title: "HUMIDITY",
                  value: "${current["humidity_pct"] ?? "-"} %",
                ),
              ],
            )
                .animate(delay: 150.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms),

            const SizedBox(height: 22),

            statusCard(risk)
                .animate(delay: 300.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms),
          ],
        ),
      ),
    );
  }
}