import 'package:flutter/material.dart';
import '../services/xai_api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';

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
    if (risk == "High") return AppColors.highRisk;
    if (risk == "Medium") return AppColors.mediumRisk;
    return AppColors.lowRisk;
  }

  Widget metricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    Color iconColor = AppColors.primary;
    Color bgColor = AppColors.lightGray;

    switch (title) {
      case "Average Temp":
        iconColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFFF4DD);
        break;

      case "Humidity":
        iconColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFEAF4FF);
        break;

      case "Rainfall":
        iconColor = const Color(0xFF06B6D4);
        bgColor = const Color(0xFFE8FCFD);
        break;

      case "Maximum Temp":
        iconColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFFF0F0);
        break;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: const Color(0xFFF1F3F7),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.subtitle,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget riskCard(
    String risk,
    double confidence,
    String formattedDate,
  ) {
    final color = riskColor(risk);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEEF4),
            Color(0xFFFFF8FB),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFE6EE),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 12),
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
                  "Today's Dengue Prediction",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$risk Risk",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "${confidence.toStringAsFixed(2)}% Model Confidence",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.view_week_rounded,
                      size: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: AppColors.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Icon(
                      Icons.date_range_rounded,
                      size: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Week ${data?["week"] ?? "-"}",
                      style: const TextStyle(
                        color: AppColors.subtitle,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  "Risk Class Probabilities",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 10),
                _riskProbabilityRow(
                  label: "Low Risk",
                  value:
                      ((data?["probabilities"]?["Low"] ?? 0) as num).toDouble(),
                  color: const Color(0xFF2EAD74),
                ),
                const SizedBox(height: 10),
                _riskProbabilityRow(
                  label: "Medium Risk",
                  value: ((data?["probabilities"]?["Medium"] ?? 0) as num)
                      .toDouble(),
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(height: 10),
                _riskProbabilityRow(
                  label: "High Risk",
                  value: ((data?["probabilities"]?["High"] ?? 0) as num)
                      .toDouble(),
                  color: const Color(0xFFFF4D73),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskProbabilityRow({
    required String label,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.subtitle,
                ),
              ),
            ),
            Text(
              "${value.toStringAsFixed(2)}%",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.title,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(
            begin: 0,
            end: value / 100,
          ),
          builder: (context, animatedValue, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: animatedValue,
                minHeight: 7,
                backgroundColor: const Color(0xFFE7EAF0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  color,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget probabilityBar({
    required String label,
    required double value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                "${value.toStringAsFixed(2)}%",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFE7EAF0),
              valueColor: AlwaysStoppedAnimation(color),
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
        color: high ? const Color(0xFFFFE4E1) : const Color(0xFFF4FFF7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: high ? const Color(0xFFFF2F6D) : Colors.green,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety,
              color: AppColors.card,
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
                    color: AppColors.body,
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
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final risk = data?["risk_level"] ?? "Unknown";
    final features = data?["auto_generated_features"] ?? {};
    final confidence = ((data?["confidence"] ?? 0) as num).toDouble();

    final formattedDate = data?["date"] != null
        ? DateFormat("dd MMM yyyy").format(
            DateTime.parse(data!["date"]),
          )
        : "-";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2F6D).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety,
                color: Color(0xFFFD5A7A),
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
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: AppColors.title,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Colombo District Monitoring",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.subtitle,
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
            // ===========================
            // AI Prediction Summary
            // ===========================
            riskCard(
              risk,
              confidence,
              formattedDate,
            )
                .animate()
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms),

            const SizedBox(height: 14),

            // ===========================
            // Weather Overview
            // ===========================

            const Row(
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: Color(0xFF4F7CFF),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  "Weather Overview",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.title,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.22,
              children: [
                metricCard(
                  icon: Icons.thermostat,
                  title: "Average Temp",
                  value: "${features["temp_mean_c"] ?? "-"} °C",
                ),
                metricCard(
                  icon: Icons.opacity,
                  title: "Humidity",
                  value: "${features["humidity_pct"] ?? "-"} %",
                ),
                metricCard(
                  icon: Icons.water_drop,
                  title: "Rainfall",
                  value: "${features["rainfall_mm"] ?? "-"} mm",
                ),
                metricCard(
                  icon: Icons.thermostat_auto,
                  title: "Maximum Temp",
                  value: "${features["temp_max_c"] ?? "-"} °C",
                ),
              ],
            )
                .animate(delay: 150.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0, duration: 700.ms),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
