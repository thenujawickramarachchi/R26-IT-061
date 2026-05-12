import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_widgets.dart';
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
  String risk = "Unknown";
  double confidence = 0;
  String? error;

  @override
  void initState() {
    super.initState();
    loadXai();
  }

  Widget shimmerCard({
    double height = 140,
  }) {
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
      final global = await ApiService.shapGlobal();
      final timeline = await ApiService.riskTimeline();
      final latestInput = await ApiService.sampleInput();
      final local = await ApiService.shapLocal(latestInput);

      setState(() {
        globalShap = global;
        riskTimeline = timeline;
        localShap = local["explanations"] ?? [];
        risk = local["risk_level"] ?? "Unknown";
        confidence = ((local["confidence"] ?? 0) as num).toDouble();
        error = null;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Failed to load XAI analysis. Check backend connection.";
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
    if (list.isEmpty) return 0;

    final v = (value as num).abs().toDouble();

    final max = list
        .map((e) => ((e[key] ?? 0) as num).abs().toDouble())
        .reduce((a, b) => a > b ? a : b);

    if (max == 0) return 0;
    return (v / max).clamp(0.0, 1.0);
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
      return "Rainfall, Humidity, Temperature";
    }

    return localShap.take(3).map((e) {
      return e["label"].toString();
    }).join(", ");
  }

  String evidenceInsight() {
    final top = topDriversText();

    return "Our SHAP feature analysis indicates that the current $risk risk prediction is mainly driven by $top. These factors provide evidence for public health officers to justify surveillance, inspection, and prevention actions.";
  }

  List<Map<String, String>> mohAreas() {
    return [
      {
        "name": "Colombo MC",
        "risk": risk == "Low" ? "Medium" : "High",
        "reason":
            "Dense urban surveillance signal with elevated dengue activity.",
      },
      {
        "name": "Maharagama",
        "risk": risk == "High" ? "High" : "Medium",
        "reason":
            "Rainfall and humidity indicate suitable breeding conditions.",
      },
      {
        "name": "Dehiwala",
        "risk": risk == "High" ? "High" : "Medium",
        "reason":
            "Climate-dengue pattern suggests elevated transmission pressure.",
      },
      {
        "name": "Nugegoda",
        "risk": "Medium",
        "reason": "Moderate dengue trend requiring continuous monitoring.",
      },
    ];
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
          const CircleAvatar(
            radius: 4,
            backgroundColor: Color(0xFFFF2F6D),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 9,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(gaugeColor),
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

  Widget riskSummaryCard() {
    final color = riskColor(risk);

    final positiveDrivers = localShap
        .where((e) => ((e["shap_value"] ?? 0) as num).toDouble() >= 0)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withAlpha((0.18 * 255).round())),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, color: Color(0xFFFF2F6D)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "REGIONAL OUTBREAK PREDICTION",
                  style: TextStyle(
                    color: Color(0xFFB3194A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: color.withAlpha((0.25 * 255).round())),
                ),
                child: const Text(
                  "Latest\nWeek",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB3194A),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  "$risk Risk\nLatest Week Prediction",
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              confidenceGauge().animate().fadeIn(duration: 500.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Text(
                  "POSITIVE IMPACT (+)",
                  style: TextStyle(
                      color: Color(0xFFFF2F6D),
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                "NEGATIVE IMPACT (-)",
                style: TextStyle(
                  color: Color(0xFF009DE0),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Expanded(
                  flex: 82,
                  child: Container(height: 14, color: const Color(0xFFFF5A7C)),
                ),
                Expanded(
                  flex: 8,
                  child: Container(height: 14, color: const Color(0xFF03A9F4)),
                ),
                Expanded(
                  flex: 10,
                  child: Container(height: 14, color: const Color(0xFFE7EEF7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: positiveDrivers.isEmpty
                ? [
                    driverChip("Rainfall"),
                    driverChip("Humidity"),
                    driverChip("Temperature"),
                  ]
                : positiveDrivers.map((e) {
                    return driverChip(e["label"].toString());
                  }).toList(),
          ),
        ],
      ),
    );
  }

  Widget shapImpactBar({
    required String label,
    required double value,
  }) {
    final isPositive = value >= 0;

    final color =
        isPositive ? const Color(0xFFFF2F6D) : const Color(0xFF00A884);

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
                isPositive ? "Risk Increase" : "Risk Reduction",
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

  Widget localBreakdownCard() {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Local SHAP Breakdown", Icons.stacked_line_chart),
          const SizedBox(height: 10),
          const Text(
            "Latest-week prediction factors from the trained Colombo dengue-weather model.",
            style: TextStyle(color: Color(0xFF7A879A), height: 1.35),
          ),
          const SizedBox(height: 18),
          ...localShap.take(6).map((item) {
            final label = item["label"].toString();
            final shapValue = (item["shap_value"] as num).toDouble();
            final absShap = (item["abs_shap"] as num).toDouble();
            final color = shapColor(shapValue);
            final positive = shapValue >= 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF60708A),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        "${positive ? '+' : '-'}${absShap.toStringAsFixed(4)} ${positive ? 'Target Contribution' : 'Risk Reduction'}",
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: normalize(absShap, localShap, "abs_shap"),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: const Color(0xFFE7EEF7),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget localGlobalComparisonCard() {
    if (localShap.isEmpty || globalShap.isEmpty) {
      return const SizedBox.shrink();
    }

    final localTop = localShap.take(5).map((e) {
      return e["label"].toString();
    }).toSet();

    final globalTop = globalShap.take(5).map((e) {
      return e["label"].toString();
    }).toSet();

    final commonDrivers = localTop.intersection(globalTop).toList();
    final uniqueLocal = localTop.difference(globalTop).toList();

    final interpretation = commonDrivers.isNotEmpty
        ? "Current weekly risk is influenced by both long-term model drivers and latest-week conditions. Common drivers include ${commonDrivers.take(3).join(", ")}."
        : "Current weekly risk is mainly influenced by short-term environmental changes rather than the strongest long-term global model drivers.";

    return SoftCard(
      color: const Color(0xFFF6F2FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Local vs Global SHAP Comparison", Icons.compare_arrows),
          const SizedBox(height: 10),
          Text(
            "Compares latest-week risk drivers with overall model behaviour across the training dataset.",
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _comparisonBox(
                  title: "Local SHAP",
                  subtitle: "Current week",
                  items: localTop.take(3).toList(),
                  color: const Color(0xFFFF2F6D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _comparisonBox(
                  title: "Global SHAP",
                  subtitle: "Full dataset",
                  items: globalTop.take(3).toList(),
                  color: const Color(0xFF5B4BFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights, color: Color(0xFF5B4BFF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    interpretation,
                    style: const TextStyle(
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (uniqueLocal.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Special current-week triggers: ${uniqueLocal.take(3).join(", ")}",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonBox({
    required String title,
    required String subtitle,
    required List<String> items,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
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

  Widget globalImportanceCard() {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Feature Importance (Global)", Icons.layers),
          const SizedBox(height: 18),
          ...globalShap.take(8).map((item) {
            final label = item["label"].toString().toUpperCase();
            final value = (item["mean_abs_shap"] as num).toDouble();
            final percent =
                (normalize(value, globalShap, "mean_abs_shap") * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF65758E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF1FB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "SHAP",
                                style: TextStyle(
                                  color: Color(0xFF8DA0B8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "$percent%",
                        style: const TextStyle(
                            color: Color(0xFF65758E),
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: normalize(value, globalShap, "mean_abs_shap"),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(20),
                    backgroundColor: const Color(0xFFE7EEF7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5B4BFF),
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

  Widget mohIntelligenceCard() {
    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("MOH Area Risk Intelligence", Icons.location_city),
          const SizedBox(height: 8),
          const Text(
            "Spatial interpretation layer for Colombo district surveillance.",
            style: TextStyle(color: Color(0xFF7A879A)),
          ),
          const SizedBox(height: 16),
          ...mohAreas().map((moh) {
            final color = riskColor(moh["risk"]!);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: color,
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          moh["name"]!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          moh["reason"]!,
                          style: const TextStyle(
                            color: Color(0xFF65758E),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      moh["risk"]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
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

  Widget whyHighRiskCard() {
    final topDrivers = localShap.take(3).toList();

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Why $risk Risk?", Icons.psychology),
          const SizedBox(height: 10),
          Text(
            "The prediction was mainly influenced by the following SHAP drivers from the trained dengue-climate model.",
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...topDrivers.map((driver) {
            final value = ((driver["shap_value"] ?? 0) as num).toDouble();

            final positive = value >= 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: positive
                    ? const Color(0xFFFFF0F4)
                    : const Color(0xFFEFFAF7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: positive
                        ? const Color(0xFFFF2F6D)
                        : const Color(0xFF009688),
                    child: Icon(
                      positive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver["label"].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          positive
                              ? "This feature increased dengue outbreak risk."
                              : "This feature reduced outbreak risk.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    value.toStringAsFixed(3),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: positive
                          ? const Color(0xFFFF2F6D)
                          : const Color(0xFF009688),
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

  Widget interventionCard() {
    final recommendations = <String>[];

    if (risk.toLowerCase().contains("high")) {
      recommendations.addAll([
        "Increase MOH field inspections in high-risk zones",
        "Remove stagnant water breeding locations",
        "Issue public awareness notifications",
        "Monitor rainfall and humidity fluctuations",
      ]);
    } else if (risk.toLowerCase().contains("medium")) {
      recommendations.addAll([
        "Continue weekly dengue surveillance",
        "Monitor climate-condition changes",
        "Conduct targeted awareness campaigns",
      ]);
    } else {
      recommendations.addAll([
        "Maintain routine dengue prevention activities",
        "Continue environmental monitoring",
      ]);
    }

    return SoftCard(
      color: const Color(0xFFEEF5FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            "Recommended Public Health Actions",
            Icons.health_and_safety,
          ),
          const SizedBox(height: 12),
          Text(
            "Evidence-based intervention recommendations generated from the current dengue risk analysis.",
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...recommendations.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle,
                      color: riskColor(risk),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
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

  Widget riskTimelineCard() {
    if (riskTimeline.isEmpty) {
      return const SizedBox.shrink();
    }

    Color getRiskColor(String level) {
      switch (level.toLowerCase()) {
        case "high":
          return const Color(0xFFFF2F6D);
        case "medium":
          return Colors.orange;
        case "low":
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    return SoftCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Dengue Risk Timeline", Icons.timeline),
          const SizedBox(height: 10),
          Text(
            "Historical weekly dengue-risk predictions generated using the trained Random Forest model.",
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: riskTimeline.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 5,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final item = riskTimeline[index];

              final level = item["risk"].toString();
              final color = getRiskColor(level);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        level,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item["week"].toString(),
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${item["confidence"]}%",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget evidenceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF332C91),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF4D45A8),
                child: Icon(Icons.lightbulb, color: Colors.amber),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "EVIDENCE-BASED INSIGHT",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            evidenceInsight(),
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget researchNoteCard() {
    return const SoftCard(
      color: Color(0xFFFFF8E1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Note",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 10),
          Text(
            "The SHAP explanation is generated from the trained Colombo district dengue-weather model. The MOH section is presented as a spatial intelligence layer for dashboard interpretation and can be upgraded to true MOH-level SHAP when MOH-level training data becomes available.",
            style: TextStyle(height: 1.45),
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
                Icons.psychology,
                color: Color(0xFF5B4BFF),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Explainable AI",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "SHAP dengue risk explanation",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 26,
                  color: Color(0xFF172033),
                ),
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF2F6D),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadXai,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 100),
            children: [
              // DELETE OLD HEADER ROW FROM HERE

              if (error != null)
                SoftCard(
                  color: Colors.red.shade50,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              riskSummaryCard()
                  .animate()
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              const SizedBox(height: 24),

              localBreakdownCard()
                  .animate(delay: 120.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              whyHighRiskCard()
                  .animate(delay: 220.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              interventionCard()
                  .animate(delay: 320.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              riskTimelineCard()
                  .animate(delay: 420.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              localGlobalComparisonCard()
                  .animate(delay: 520.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              globalImportanceCard()
                  .animate(delay: 620.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              mohIntelligenceCard()
                  .animate(delay: 720.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              evidenceCard()
                  .animate(delay: 820.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),

              const SizedBox(height: 16),

              researchNoteCard()
                  .animate(delay: 920.ms)
                  .fade(duration: 700.ms)
                  .slideY(begin: 0.25, end: 0, duration: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}
