import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  bool loading = true;
  List<dynamic> history = [];

  @override
  void initState() {
    super.initState();
    loadTrend();
  }

  Future<void> loadTrend() async {
    try {
      final res = await ApiService.history();

      debugPrint("===== HISTORY DATA =====");
      debugPrint(res.toString());

      setState(() {
        history = res;
        loading = false;
      });
    } catch (e) {
      debugPrint("===== HISTORY ERROR =====");
      debugPrint(e.toString());

      setState(() {
        loading = false;
      });
    }
  }

  Widget softCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget insightCard() {
    if (history.isEmpty) {
      return softCard(
        child: const Text(
          "No trend information is currently available.",
          style: TextStyle(
            color: Color(0xFF5F6B7A),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final cases = history
        .map((e) => ((e["dengue_cases"] ?? 0) as num).toDouble())
        .toList();

    final firstCases = cases.first;
    final latestCases = cases.last;

    final highestCases = cases.reduce(
      (a, b) => a > b ? a : b,
    );

    final lowestCases = cases.reduce(
      (a, b) => a < b ? a : b,
    );

    final highestIndex = cases.indexOf(highestCases);

    final highestWeek = history[highestIndex]["week"]?.toString() ?? "-";

    final highestYear = history[highestIndex]["year"]?.toString() ?? "-";

    final changePercent =
        firstCases == 0 ? 0 : ((latestCases - firstCases) / firstCases) * 100;

    String trendText;

    if (changePercent > 10) {
      trendText =
          "Dengue cases show an increasing trend across the latest ${history.length} weeks.";
    } else if (changePercent < -10) {
      trendText =
          "Dengue cases show a decreasing trend across the latest ${history.length} weeks.";
    } else {
      trendText =
          "Dengue cases remained relatively stable across the latest ${history.length} weeks.";
    }

    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF5B4BFF),
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Trend Insight",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF172033),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Based on the latest available records",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A94A6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            trendText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F6B7A),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: insightMetric(
                  title: "Latest",
                  value: "${latestCases.toInt()}",
                  subtitle: "cases",
                  icon: Icons.show_chart_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: insightMetric(
                  title: "Peak",
                  value: "${highestCases.toInt()}",
                  subtitle: "W$highestWeek",
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: insightMetric(
                  title: "Change",
                  value:
                      "${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(0)}%",
                  subtitle: "period",
                  icon: Icons.percent_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Highest recorded level: Week $highestWeek, $highestYear "
            "with ${highestCases.toInt()} dengue cases. "
            "Lowest recorded level: ${lowestCases.toInt()} cases.",
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A94A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget insightMetric({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
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
          color: const Color(0xFFE5EBF7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF5B4BFF),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A94A6),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A94A6),
            ),
          ),
        ],
      ),
    );
  }

  Widget latestRecordsCard() {
    final latest = history.reversed.take(5).toList();

    return softCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Latest Weekly Records",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF172033),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Recent dengue and weather observations",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A94A6),
            ),
          ),
          const SizedBox(height: 18),
          ...latest.asMap().entries.map((entry) {
            final w = entry.value;

            final week = w["week"]?.toString() ?? "-";
            final year = w["year"]?.toString() ?? "-";

            final cases = ((w["dengue_cases"] ?? 0) as num).toDouble();

            final rainfall = ((w["rainfall_mm"] ?? 0) as num).toDouble();

            final humidity = ((w["humidity_pct"] ?? 0) as num).toDouble();

            final temperature = ((w["temp_mean_c"] ?? 0) as num).toDouble();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFE8EDF6),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Week icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF5B4BFF),
                      size: 23,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Main information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Week $week, $year",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Rainfall ${rainfall.toStringAsFixed(1)} mm  •  "
                          "Humidity ${humidity.toStringAsFixed(1)}%",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6F7B8C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Temperature ${temperature.toStringAsFixed(1)}°C",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6F7B8C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Dengue cases
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        cases.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFF2F6D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "cases",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8A94A6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
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

    final spots = history.asMap().entries.map((entry) {
      final y = ((entry.value["dengue_cases"] ?? 0) as num).toDouble();
      return FlSpot(entry.key.toDouble(), y);
    }).toList();

    final avgRainfall = history.isNotEmpty
        ? history
                .map((e) => ((e["rainfall_mm"] ?? 0) as num).toDouble())
                .reduce((a, b) => a + b) /
            history.length
        : 0;

    final avgHumidity = history.isNotEmpty
        ? history
                .map((e) => ((e["humidity_pct"] ?? 0) as num).toDouble())
                .reduce((a, b) => a + b) /
            history.length
        : 0;

    final avgTemp = history.isNotEmpty
        ? history
                .map((e) => ((e["temp_mean_c"] ?? 0) as num).toDouble())
                .reduce((a, b) => a + b) /
            history.length
        : 0;

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
                Icons.show_chart,
                color: Color(0xFF5B4BFF),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trend Analysis",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Colombo district outbreak trends",
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
        onRefresh: loadTrend,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
          children: [
            softCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Weekly Dengue Case Trend",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF172033),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Last 12 epidemiological weeks",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8A94A6),
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
                          color: const Color(0xFFEFFBFD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD5F1F5),
                          ),
                        ),
                        child: const Text(
                          "12 WEEKS",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Color(0xFF159FB5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 245,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 100,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withValues(alpha: 0.15),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 100,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF8A94A6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();

                                if (index < 0 || index >= history.length) {
                                  return const SizedBox.shrink();
                                }

                                final label =
                                    history[index]["label"]?.toString() ?? "";

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label.replaceFirst(
                                      RegExp(r'^\d{4}-'),
                                      '',
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF8A94A6),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 5,
                            color: const Color(0xFF17B6CF),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF17B6CF)
                                  .withValues(alpha: 0.15),
                            ),
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,

                          // Make the interaction area around each data point easier to detect.
                          touchSpotThreshold: 45,

                          handleBuiltInTouches: true,

                          mouseCursorResolver: (event, response) {
                            if (response?.lineBarSpots != null &&
                                response!.lineBarSpots!.isNotEmpty) {
                              return SystemMouseCursors.click;
                            }

                            return SystemMouseCursors.basic;
                          },

                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF172033),
                            tooltipRoundedRadius: 14,
                            tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            tooltipMargin: 12,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final index = spot.x.toInt();

                                if (index < 0 || index >= history.length) {
                                  return null;
                                }

                                final data = history[index];

                                final week = data["label"]?.toString() ?? "";

                                final cases =
                                    ((data["dengue_cases"] ?? 0) as num)
                                        .toInt();

                                final rainfall =
                                    ((data["rainfall_mm"] ?? 0) as num)
                                        .toDouble();

                                final humidity =
                                    ((data["humidity_pct"] ?? 0) as num)
                                        .toDouble();

                                return LineTooltipItem(
                                  "$week\n"
                                  "$cases dengue cases\n"
                                  "Rainfall ${rainfall.toStringAsFixed(1)} mm\n"
                                  "Humidity ${humidity.toStringAsFixed(1)}%",
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.45,
                                  ),
                                );
                              }).toList();
                            },
                          ),

                          getTouchedSpotIndicator: (
                            barData,
                            spotIndexes,
                          ) {
                            return spotIndexes.map((index) {
                              return TouchedSpotIndicatorData(
                                const FlLine(
                                  color: Color(0xFF17B6CF),
                                  strokeWidth: 2,
                                  dashArray: [4, 4],
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter: (
                                    spot,
                                    percent,
                                    barData,
                                    index,
                                  ) {
                                    return FlDotCirclePainter(
                                      radius: 6,
                                      color: const Color(0xFF17B6CF),
                                      strokeWidth: 3,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(duration: 700.ms).slideY(begin: 0.25, end: 0),
            const SizedBox(height: 20),
            softCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Climate Averages",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      climateItem(
                        "Rainfall",
                        "${avgRainfall.toStringAsFixed(1)} mm",
                        Icons.water_drop,
                      ),
                      climateItem(
                        "Humidity",
                        "${avgHumidity.toStringAsFixed(1)}%",
                        Icons.opacity,
                      ),
                      climateItem(
                        "Temperature",
                        "${avgTemp.toStringAsFixed(1)}°C",
                        Icons.thermostat,
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate(delay: 150.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0),
            const SizedBox(height: 20),
            insightCard()
                .animate(delay: 300.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0),
            const SizedBox(height: 20),
            latestRecordsCard()
                .animate(delay: 450.ms)
                .fade(duration: 700.ms)
                .slideY(begin: 0.25, end: 0),
          ],
        ),
      ),
    );
  }

  Widget climateItem(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE3EAF8),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF5B4BFF),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF172033),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A94A6),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
