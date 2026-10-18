import 'package:flutter/material.dart';
import '../services/xai_api_service.dart';
import '../widgets/xai_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

class ExplainScreen extends StatefulWidget {
  const ExplainScreen({super.key});

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  bool loading = true;
  List<dynamic> globalShap = [];
  List<dynamic> riskTimeline = [];
  List<dynamic> localShap = [];
  Map<String, dynamic> dashboardData = {};
  String risk = "Unknown";
  double confidence = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    loadXai();
  }

  Widget shimmerCard({double height = 140}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Future<void> loadXai() async {
    try {
      // =====================================================
      // 1. TODAY'S REAL DASHBOARD DATA
      // =====================================================
      final dashboard = await ApiService.dashboard();

      final currentRisk = dashboard["risk_level"];
      final currentConfidence = dashboard["confidence"];

      if (currentRisk == null || currentConfidence == null) {
        throw Exception("Dashboard prediction data is unavailable");
      }

      // =====================================================
      // 2. GET YEAR + WEEK AUTOMATICALLY
      //    No manual input
      // =====================================================
      final year = dashboard["year"];
      final week = dashboard["week"];

      if (year == null || week == null) {
        throw Exception("Dashboard year/week data is unavailable");
      }

      // =====================================================
      // 3. REAL GLOBAL SHAP
      // =====================================================
      final global = await ApiService.shapGlobal();

      // =====================================================
      // 4. REAL LOCAL SHAP
      //    Year + Week come automatically from dashboard
      // =====================================================
      final localResponse = await ApiService.shapLocal({
        "year": year,
        "week": week,
      });

      final rawLocal = localResponse["local_shap"];

      if (rawLocal == null || rawLocal is! List) {
        throw Exception("Local SHAP data is unavailable");
      }

      // =====================================================
      // 5. CONVERT REAL LOCAL SHAP RESPONSE
      // =====================================================
      final parsedLocal = rawLocal.map((item) {
        if (item is! Map) {
          throw Exception("Invalid Local SHAP item");
        }

        final shapValue = (item["shap_value"] as num?)?.toDouble();

        final featureValue = (item["value"] as num?)?.toDouble();

        final feature = item["feature"]?.toString();

        if (feature == null || shapValue == null || featureValue == null) {
          throw Exception("Invalid Local SHAP response");
        }

        return {
          "label": feature,
          "value": featureValue,
          "shap_value": shapValue,
          "abs_shap": shapValue.abs(),
        };
      }).toList();

      // =====================================================
      // 6. OPTIONAL REAL RISK TIMELINE
      // =====================================================
      List<dynamic> timeline = [];

      try {
        timeline = await ApiService.riskTimeline();
      } catch (_) {
        // Timeline unavailable.
        // Do NOT break the main XAI page.
        timeline = [];
      }

      // =====================================================
      // 8. UPDATE SCREEN WITH REAL DATA
      // =====================================================
      setState(() {
        risk = currentRisk.toString();

        confidence = (currentConfidence as num).toDouble();

        globalShap = global;

        localShap = parsedLocal;

        riskTimeline = timeline;

        dashboardData = dashboard;

        loading = false;

        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();

        loading = false;
      });
    }
  }

  Color riskColor(String value) {
    if (value == "High") return const Color(0xFFE91E63);
    if (value == "Medium") return const Color(0xFFFF9800);
    if (value == "Low") return const Color(0xFF2E7D32);
    return Colors.grey;
  }

  Color shapColor(num value) {
    if (value > 0) return const Color(0xFFFF2F6D);
    if (value < 0) return const Color(0xFF009688);
    return Colors.grey;
  }

  double normalize(dynamic value, List<dynamic> list, String key) {
    if (list.isEmpty || value is! num) {
      return 0;
    }

    final current = value.abs().toDouble();

    final values = list
        .whereType<Map>()
        .map((item) => item[key])
        .whereType<num>()
        .map((number) => number.abs().toDouble())
        .toList();

    if (values.isEmpty) {
      return 0;
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);

    if (maxValue == 0) {
      return 0;
    }

    return (current / maxValue).clamp(0.0, 1.0);
  }

  int confidencePercent() {
    return confidence.round();
  }

  String confidenceLabel() {
    if (confidence >= 80) return "Strong Confidence";
    if (confidence >= 60) return "Moderate Confidence";
    return "Low Confidence";
  }

  String topDriversText() {
    if (localShap.isEmpty) {
      return "";
    }

    return localShap.take(3).map((e) => e["label"].toString()).join(", ");
  }

  String evidenceInsight() {
    final top = topDriversText();

    return "Our SHAP feature analysis indicates that the current $risk risk prediction is mainly driven by $top. These factors provide evidence for public health officers to justify surveillance, inspection, and prevention actions.";
  }

  Widget sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4B3CFA)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
        ),
      ],
    );
  }

  Widget driverChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF2F6D)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget confidenceGauge() {
    final percent = confidence.clamp(0, 100) / 100;

    Color gaugeColor;

    String label;

    if (confidence >= 75) {
      gaugeColor = Colors.green;
      label = "High Confidence";
    } else if (confidence >= 50) {
      gaugeColor = Colors.orange;
      label = "Moderate Confidence";
    } else {
      gaugeColor = const Color(0xFFFF2F6D);
      label = "Low Confidence";
    }

    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(
                  value: (confidence / 100).clamp(0.0, 1.0),
                  strokeWidth: 4,
                  backgroundColor: const Color(0xFFE8EDF5),
                  valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${confidence.toStringAsFixed(0)}%",
                    style: TextStyle(
                      color: gaugeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Confidence",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A879A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: gaugeColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _realDriverChip({
    required String feature,
    required double value,
    required double shapValue,
  }) {
    final isPositive = shapValue >= 0;

    final displayValue = value.toStringAsFixed(2);

    final displayShap = shapValue.abs().toStringAsFixed(4);

    final accentColor = isPositive
        ? const Color(0xFFFF477E)
        : const Color(0xFF00A6A6);

    final backgroundColor = isPositive
        ? const Color(0xFFFFF3F6)
        : const Color(0xFFF0FAFA);

    return Container(
      constraints: const BoxConstraints(minWidth: 155),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 18,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  feature,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Observed: $displayValue",
                  style: const TextStyle(
                    color: Color(0xFF7E8A9D),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPositive ? "+$displayShap" : "-$displayShap",
                style: TextStyle(
                  color: accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "SHAP",
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.65),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget shapImpactBar({required String label, required double value}) {
    final isPositive = value >= 0;

    final color = isPositive
        ? const Color(0xFFFF2F6D)
        : const Color(0xFF00A884);

    final percent = (value.abs() * 100).clamp(8, 100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                "${isPositive ? '+' : '-'}${value.abs().toStringAsFixed(4)}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isPositive ? "Positive contribution" : "Negative contribution",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  String _factorDescription(String feature) {
    final name = feature.toLowerCase();

    if (name.contains('temp')) {
      return 'Affects mosquito development and virus growth.';
    } else if (name.contains('humid')) {
      return 'Influences mosquito survival and activity.';
    } else if (name.contains('rain') || name.contains('precipitation')) {
      return 'Can create mosquito breeding sites.';
    }

    return 'This factor helps identify dengue patterns.';
  }

  Widget globalImportanceCard() {
    if (globalShap.isEmpty) {
      return const SizedBox.shrink();
    }

    final validGlobalShap =
        globalShap.where((item) {
          return item is Map &&
              item["feature"] != null &&
              item["importance"] is num;
        }).toList()..sort(
          (a, b) => (b["importance"] as num).compareTo(a["importance"] as num),
        );

    if (validGlobalShap.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayedFactors = validGlobalShap.take(6).toList();

    final topFeature = _friendlyGlobalFeature(
      displayedFactors.first["feature"].toString(),
    );

    final maxImportance =
        (displayedFactors
                .map((item) => (item["importance"] as num).abs())
                .fold<double>(
                  0.0,
                  (previous, value) =>
                      value.toDouble() > previous ? value.toDouble() : previous,
                ))
            .toDouble();

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEE9FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Which Factors Matter Most to the AI?",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Overall feature importance",
                      style: TextStyle(
                        color: Color(0xFF7E8A9D),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${displayedFactors.length} factors",
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Explain what global importance means in simple language.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E3FF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "$topFeature is the most important feature "
                    "among those shown across the overall results. "
                    "This does not necessarily mean it contributed most "
                    "to the current prediction.",
                    style: const TextStyle(
                      color: Color(0xFF536174),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "FEATURE RANKING",
            style: TextStyle(
              color: Color(0xFF8792A6),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),

          const SizedBox(height: 14),

          ...displayedFactors.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            final rawFeature = item["feature"].toString();
            final feature = _friendlyGlobalFeature(rawFeature);
            final importance = (item["importance"] as num).toDouble();

            final normalized = maxImportance == 0
                ? 0.0
                : (importance.abs() / maxImportance).clamp(0.0, 1.0).toDouble();

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == displayedFactors.length - 1 ? 0 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEDFF),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            color: Color(0xFF5B4BFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: Color(0xFF263247),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        importance.toStringAsFixed(4),
                        style: const TextStyle(
                          color: Color(0xFF5B5CE2),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: normalized,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE9EDF5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6A5DF5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    index == 0
                        ? "Highest overall importance"
                        : "Ranked ${index + 1} by importance",
                    style: const TextStyle(
                      color: Color(0xFF8994A7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE3E0FF)),
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        visualDensity: const VisualDensity(vertical: -2),
                        minTileHeight: 48,
                        iconColor: const Color(0xFF5B4BFF),
                        collapsedIconColor: const Color(0xFF5B4BFF),
                        title: const Text(
                          'Learn About This Factor',
                          style: TextStyle(
                            color: Color(0xFF344054),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _factorDescription(feature),
                              style: const TextStyle(
                                color: Color.fromARGB(255, 37, 37, 37),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFE9EDF5)),
          const SizedBox(height: 10),

          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF5B5CE2),
                size: 17,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "How to read this: longer bars indicate greater overall "
                  "feature importance. These scores are not dengue-risk "
                  "percentages; see the section above for this prediction's "
                  "explanation.",
                  style: TextStyle(
                    color: Color(0xFF65758E),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _friendlyGlobalFeature(String feature) {
    final normalized = feature
        .trim()
        .toLowerCase()
        .replaceAll("-", "_")
        .replaceAll(" ", "_");

    switch (normalized) {
      case "temperature":
      case "temp":
      case "temp_mean_c":
      case "mean_temperature":
      case "temperature_mean":
        return "Temperature";

      case "rainfall":
      case "rainfall_mm":
      case "rain":
      case "precipitation":
        return "Rainfall";

      case "humidity":
      case "humidity_pct":
      case "relative_humidity":
        return "Humidity";

      case "year":
        return "Year";

      case "week":
      case "week_of_year":
        return "Week of year";

      case "month":
        return "Month";

      default:
        return feature
            .replaceAll("_", " ")
            .replaceAll("-", " ")
            .split(" ")
            .where((word) => word.isNotEmpty)
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(" ");
    }
  }

  Widget overallDistrictRiskCard() {
    final currentRisk = risk.toUpperCase();
    final currentRiskColor = riskColor(risk);

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "COLOMBO DISTRICT",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Current Overall Dengue Risk",
                      style: TextStyle(
                        color: Color(0xFF7E8A9D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: currentRiskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: currentRiskColor.withValues(alpha: 0.20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CURRENT PREDICTION",
                        style: TextStyle(
                          color: Color.fromARGB(255, 3, 3, 3),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$currentRisk RISK",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ).copyWith(color: currentRiskColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: currentRiskColor, width: 4),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${confidence.toStringAsFixed(0)}%",
                          style: TextStyle(
                            color: currentRiskColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          "Confidence",
                          style: TextStyle(
                            color: Color(0xFF7E8A9D),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            "This is the current overall dengue risk prediction for the Colombo District.",
            style: TextStyle(
              color: Color.fromARGB(255, 2, 2, 2),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget riskMeaningCard() {
    final String meaning;

    switch (risk.toLowerCase()) {
      case "high":
        meaning =
            "Current Colombo District dengue risk as High. This indicates an elevated risk category, but it does not confirm that an outbreak will occur.";
        break;
      case "medium":
        meaning =
            "Current Colombo District dengue risk as Medium. This indicates an intermediate risk category. Continue monitoring the risk information and its contributing factors.";
        break;
      case "low":
        meaning =
            "Current Colombo District dengue risk as Low. This is the current risk category, but it does not mean that dengue risk is completely absent.";
        break;
      default:
        meaning =
            "The current dengue risk category is unavailable or could not be interpreted.";
    }

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("What Does This Risk Mean?", Icons.info_outline_rounded),
          const SizedBox(height: 12),
          Text(
            meaning,
            style: const TextStyle(
              color: Color.fromARGB(255, 10, 10, 10),
              fontSize: 12,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "This is an AI-generated risk classification, not a guarantee of future dengue cases.",
              style: TextStyle(
                color: Color(0xFF59677B),
                fontSize: 11,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget interpretationCard() {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            "How to Interpret This Prediction",
            Icons.insights_rounded,
          ),
          const SizedBox(height: 8),
          const Text(
            "The risk category indicates the assessed risk, while confidence reflects the certainty of that classification. Neither guarantees whether dengue cases will occur.",
            style: TextStyle(
              color: Color(0xFF65758E),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget whyHighRiskCard() {
    final drivers = localShap.where((driver) {
      return driver is Map &&
          driver["label"] != null &&
          driver["shap_value"] is num &&
          driver["value"] is num;
    }).toList();

    drivers.sort((a, b) {
      final aValue = (a["shap_value"] as num).abs();
      final bValue = (b["shap_value"] as num).abs();
      return bValue.compareTo(aValue);
    });

    final topDrivers = drivers.take(3).toList();

    if (topDrivers.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxMagnitude = topDrivers
        .map((d) => (d["shap_value"] as num).abs().toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    String friendlyName(String feature) {
      final f = feature.trim().toLowerCase().replaceAll('-', '_');

      if (f.contains('temp')) return 'Temperature';
      if (f.contains('rain') || f.contains('precipitation')) {
        return 'Rainfall';
      }
      if (f.contains('humid')) return 'Humidity';
      if (f.contains('wind')) return 'Wind Speed';
      if (f.contains('dew_point')) return 'Dew Point';

      return feature
          .replaceAll('_', ' ')
          .split(' ')
          .where((word) => word.isNotEmpty)
          .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
    }

    String unitFor(String feature) {
      final f = feature.toLowerCase();

      if (f.contains('temp')) return '°C';
      if (f.contains('rain') || f.contains('precipitation')) {
        return ' mm';
      }
      if (f.contains('humid')) return '%';
      if (f.contains('wind')) return ' m/s';
      if (f.contains('dew_point')) return '°C';

      return '';
    }

    String buildStory() {
      final names = topDrivers
          .map((driver) => friendlyName(driver["label"].toString()))
          .toList();

      final shapValues = topDrivers
          .map((driver) => (driver["shap_value"] as num).toDouble())
          .toList();

      final largestFeature = names.first;

      final allPositive = shapValues.every((value) => value > 0);
      final allNegative = shapValues.every((value) => value < 0);

      String directionText;

      if (allPositive) {
        directionText =
            "All displayed SHAP contributions are positive "
            "for the output being explained.";
      } else if (allNegative) {
        directionText =
            "All displayed SHAP contributions are negative "
            "for the output being explained.";
      } else {
        directionText =
            "The displayed features contributed in different "
            "directions to the output.";
      }

      return "$largestFeature had the largest contribution "
          "in magnitude among the factors shown. $directionText";
    }

    const positiveColor = Color(0xFFE83E75);
    const negativeColor = Color(0xFF009688);
    const neutralColor = Color(0xFF667085);

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Why Did the AI Make This Prediction?',
            Icons.psychology_alt_rounded,
          ),
          const SizedBox(height: 8),
          const Text(
            'See which input factors contributed most to the '
            'current Colombo District prediction.',
            style: TextStyle(
              color: Color(0xFF7E8A9D),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Short, user-friendly summary.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F3FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E2FF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    buildStory(),
                    style: const TextStyle(
                      color: Color(0xFF39415C),
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'SHAP CONTRIBUTIONS',
            style: TextStyle(
              color: Color(0xFF7E8A9D),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each bar shows the direction and relative size of '
            'a factor’s contribution to the output.',
            style: TextStyle(
              color: Color(0xFF667085),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),

          // Chart legend.
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: positiveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Positive contribution',
                    style: TextStyle(
                      color: neutralColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: negativeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Negative contribution',
                    style: TextStyle(
                      color: neutralColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Signed horizontal contribution chart.
          ...topDrivers.map((driver) {
            final feature = driver['label'].toString();
            final name = friendlyName(feature);
            final value = (driver['value'] as num).toDouble();
            final shapValue = (driver['shap_value'] as num).toDouble();
            final magnitude = shapValue.abs();
            final barColor = shapValue > 0
                ? positiveColor
                : shapValue < 0
                ? negativeColor
                : Colors.grey;

            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${value.toStringAsFixed(2)}${unitFor(feature)}',
                        style: const TextStyle(
                          color: Color(0xFF475467),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Contribution: ${shapValue > 0 ? '+' : ''}'
                    '${shapValue.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Zero line is in the centre.
                  SizedBox(
                    height: 24,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartWidth = constraints.maxWidth;
                        final halfWidth = chartWidth / 2;
                        final availableBarWidth = (halfWidth - 3).clamp(
                          0.0,
                          halfWidth,
                        );

                        final fraction = maxMagnitude == 0
                            ? 0.0
                            : (magnitude / maxMagnitude)
                                  .clamp(0.0, 1.0)
                                  .toDouble();

                        final barWidth = availableBarWidth * fraction;

                        return Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 8,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9EDF5),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),

                            // Negative contribution extends left.
                            if (shapValue < 0)
                              Positioned(
                                left: halfWidth - barWidth,
                                width: barWidth,
                                top: 8,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: negativeColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),

                            // Positive contribution extends right.
                            if (shapValue > 0)
                              Positioned(
                                left: halfWidth,
                                width: barWidth,
                                top: 8,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: positiveColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),

                            // Central zero reference line.
                            Positioned(
                              left: halfWidth - 1,
                              top: 2,
                              bottom: 2,
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF344054),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Negative contribution',
                        style: TextStyle(
                          color: Color.fromARGB(255, 40, 41, 43),
                          fontSize: 9,
                        ),
                      ),
                      Text(
                        '0',
                        style: TextStyle(
                          color: Color.fromARGB(255, 32, 33, 36),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Positive contribution',
                        style: TextStyle(
                          color: Color.fromARGB(255, 40, 41, 43),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE3E0FF)),
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        visualDensity: const VisualDensity(vertical: -2),
                        minTileHeight: 44,
                        iconColor: const Color(0xFF5B4BFF),
                        collapsedIconColor: const Color(0xFF5B4BFF),
                        title: const Text(
                          'About This Factor',
                          style: TextStyle(
                            color: Color(0xFF344054),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _factorDescription(name),
                              style: const TextStyle(
                                color: Color(0xFF536174),
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Optional technical details.
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: const Icon(
              Icons.science_outlined,
              color: Color(0xFF5B4BFF),
            ),
            title: const Text(
              'Technical explanation (SHAP)',
              style: TextStyle(
                color: Color(0xFF344054),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'View numerical contribution values',
              style: TextStyle(color: Color(0xFF7E8A9D), fontSize: 10),
            ),
            children: topDrivers.map((driver) {
              final feature = friendlyName(driver['label'].toString());
              final shapValue = (driver['shap_value'] as num).toDouble();

              final color = shapValue > 0
                  ? positiveColor
                  : shapValue < 0
                  ? negativeColor
                  : neutralColor;

              return ListTile(
                dense: true,
                title: Text(feature, style: const TextStyle(fontSize: 12)),
                subtitle: Text(
                  shapValue > 0
                      ? 'Positive contribution to output'
                      : shapValue < 0
                      ? 'Negative contribution to output'
                      : 'Zero contribution',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Text(
                  '${shapValue > 0 ? '+' : ''}'
                  '${shapValue.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),

          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontSize: 13,
                height: 1.55,
              ),
              children: [
                const TextSpan(
                  text: "How to understand this: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      "${friendlyName(topDrivers.first['label'].toString())} "
                      "has the largest contribution among the factors shown. "
                      "Positive and negative values indicate different contribution directions, "
                      "but do not directly mean dengue risk increases or decreases.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget interventionCard() {
    final rawRecommendations = dashboardData["recommendations"];

    if (rawRecommendations is! List || rawRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final recommendations = rawRecommendations.whereType<Map>().toList();

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEAF8F3), Color(0xFFDDF2EA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Color(0xFF16836B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recommended Actions",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      "AI-guided response measures",
                      style: TextStyle(
                        color: Color(0xFF7E8A9D),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF16836B).withValues(alpha: 0.10),
                  ),
                ),
                child: Text(
                  "${recommendations.length} actions",
                  style: const TextStyle(
                    color: Color(0xFF16836B),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Premium Information Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FAF8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF16836B),
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "The following response measures are generated from the current dengue risk prediction.",
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ...recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            final title = item["title"]?.toString();
            final priority = item["priority"]?.toString();
            final reason = item["reason"]?.toString();

            final recommendationConfidence = item["confidence"] is num
                ? (item["confidence"] as num).toDouble()
                : null;

            if (title == null || title.isEmpty) {
              return const SizedBox.shrink();
            }

            final priorityText = priority != null && priority.isNotEmpty
                ? priority
                : "Action";

            // Priority-based colors
            Color accentColor;

            switch (priorityText.toLowerCase()) {
              case "high":
                accentColor = const Color(0xFFE85D75); // Soft red
                break;

              case "medium":
                accentColor = const Color(0xFFD99020); // Warm amber
                break;

              case "low":
                accentColor = const Color(0xFF16836B); // Professional green
                break;

              default:
                accentColor = const Color(0xFF7E8A9D); // Neutral grey
            }

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFCFE),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: accentColor.withValues(alpha: 0.13)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Number / Check
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFF172033),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                priorityText,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (reason != null && reason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            reason,
                            style: const TextStyle(
                              color: Color(0xFF65758E),
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (recommendationConfidence != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 1,
                            color: accentColor.withValues(alpha: 0.10),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Recommendation confidence",
                                style: TextStyle(
                                  color: Color(0xFF7E8A9D),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${(recommendationConfidence * 100).toStringAsFixed(0)}%",
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color priorityColor(String? priority) {
    switch (priority?.trim().toLowerCase()) {
      case "high":
        return const Color(0xFFE85D75);
      case "medium":
        return const Color(0xFFD99020);
      case "low":
        return const Color(0xFF16836B);
      default:
        return const Color(0xFF7E8A9D);
    }
  }

  Widget riskTimelineCard() {
    if (riskTimeline.isEmpty) {
      return const SizedBox.shrink();
    }

    final validTimeline = riskTimeline.where((item) {
      return item is Map;
    }).toList();

    if (validTimeline.isEmpty) {
      return const SizedBox.shrink();
    }

    Color timelineRiskColor(String level) {
      switch (level.toLowerCase()) {
        case "high":
          return const Color(0xFFE53935);

        case "medium":
          return const Color(0xFFFF9800);

        case "low":
          return const Color(0xFF2EAD74);

        default:
          return const Color(0xFF7E8A9D);
      }
    }

    IconData timelineRiskIcon(String level) {
      switch (level.toLowerCase()) {
        case "high":
          return Icons.trending_up_rounded;

        case "medium":
          return Icons.remove_rounded;

        case "low":
          return Icons.trending_down_rounded;

        default:
          return Icons.analytics_outlined;
      }
    }

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEFF3FF), Color(0xFFE4EAFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.timeline_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Risk Evolution",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Recent prediction history",
                      style: TextStyle(
                        color: Color(0xFF7E8A9D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
                  color: const Color(0xFFF1F4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${validTimeline.length} weeks",
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "This timeline provides temporal context by showing how dengue risk predictions have changed across recent weeks.",
            style: TextStyle(
              color: Color(0xFF6F7C91),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 158,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: validTimeline.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = validTimeline[index];

                final riskLevel =
                    item["risk"]?.toString() ??
                    item["risk_level"]?.toString() ??
                    "Unknown";

                final week = item["week"]?.toString() ?? "-";

                final year = item["year"]?.toString() ?? "";

                final confidence = item["confidence"] is num
                    ? (item["confidence"] as num).toDouble()
                    : null;

                final color = timelineRiskColor(riskLevel);

                final icon = timelineRiskIcon(riskLevel);

                return Container(
                  width: 112,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.16)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF172033).withValues(alpha: 0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 19),
                          ),
                          const Spacer(),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        "Week $week",
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      if (year.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          year,
                          style: const TextStyle(
                            color: Color(0xFF8A94A6),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        riskLevel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (confidence != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          "${confidence.toStringAsFixed(1)}% confidence",
                          style: const TextStyle(
                            color: Color(0xFF7E8A9D),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget evidenceCard() {
    if (dashboardData.isEmpty) {
      return const SizedBox.shrink();
    }

    final modelUsed = dashboardData["model_used"]?.toString();

    final validation = dashboardData["validation"]?.toString();

    final inputType = dashboardData["input_type"]?.toString();

    final note = dashboardData["important_note"]?.toString();

    final hasModelInfo = modelUsed != null && modelUsed.isNotEmpty;

    final hasValidation = validation != null && validation.isNotEmpty;

    final hasInputType = inputType != null && inputType.isNotEmpty;

    final hasNote = note != null && note.isNotEmpty;

    if (!hasModelInfo && !hasValidation && !hasInputType && !hasNote) {
      return const SizedBox.shrink();
    }

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Prediction Evidence", Icons.fact_check_outlined),
          const SizedBox(height: 8),
          const Text(
            "Model and prediction information returned by the deployed API.",
            style: TextStyle(color: Color(0xFF7A879A), height: 1.4),
          ),
          const SizedBox(height: 18),
          if (hasModelInfo) _evidenceRow("Model", modelUsed!),
          if (hasValidation) _evidenceRow("Validation", validation!),
          if (hasInputType) _evidenceRow("Input Type", inputType!),
          if (hasNote)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                note!,
                style: const TextStyle(
                  color: Color(0xFF65758E),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _evidenceRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF8A94A6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget researchNoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F9FF), Color(0xFFF3F5FC)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF5B5CE2),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "AI Transparency",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Understanding how the prediction was generated",
                      style: TextStyle(
                        color: Color(0xFF7E8A9D),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "This screen explains the current Colombo District dengue risk prediction and highlights the factors.",
            style: TextStyle(
              color: Color(0xFF59677B),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE7EAF3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 18,
                  color: Color(0xFF5B5CE2),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "The displayed feature contributions are retrieved from the live machine-learning API rather than manually entered values.",
                    style: TextStyle(
                      color: Color(0xFF65758E),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
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
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ListView(
              children: [
                shimmerCard(height: 220),
                shimmerCard(height: 280),
                shimmerCard(height: 240),
                shimmerCard(height: 180),
                shimmerCard(height: 260),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        toolbarHeight: 78,
        centerTitle: false,
        automaticallyImplyLeading: true,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Explainable Artificial Intelligence",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "SHAP-powered risk intelligence",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadXai,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 100),
            children: [
              if (error != null)
                SoftCard(
                  color: Colors.red.shade50,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // 1. CURRENT COLOMBO DISTRICT RISK
              overallDistrictRiskCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // 2. WHAT DOES THIS RISK MEAN?
              riskMeaningCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // 3. WHY WAS THIS RISK PREDICTED?
              whyHighRiskCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // 4. GLOBAL IMPORTANCE — temporarily hidden
              // Keep globalImportanceCard() for future use.

              // 5. RISK EVOLUTION — ONLY WHEN DATA EXISTS
              if (riskTimeline.isNotEmpty) ...[
                const SizedBox(height: 16),
                riskTimelineCard()
                    .animate()
                    .fade(duration: 700.ms)
                    .slideY(begin: 0.15, end: 0),
              ],

              const SizedBox(height: 16),

              // 6. HOW TO INTERPRET THIS PREDICTION
              interpretationCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // 7. AI TRANSPARENCY
              researchNoteCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}
