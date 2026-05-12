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

      setState(() {
        history = res;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
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
    double avgHumidity = 0;
    double avgRainfall = 0;

    if (history.isNotEmpty) {
      avgHumidity = history
              .map((e) => ((e["humidity_pct"] ?? 0) as num).toDouble())
              .reduce((a, b) => a + b) /
          history.length;

      avgRainfall = history
              .map((e) => ((e["rainfall_mm"] ?? 0) as num).toDouble())
              .reduce((a, b) => a + b) /
          history.length;
    }

    return softCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.psychology,
              color: Color(0xFF5B4BFF),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Trend Insight",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172033),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Recent dengue trends indicate increased outbreak probability during periods of elevated humidity (${avgHumidity.toStringAsFixed(1)}%) and rainfall (${avgRainfall.toStringAsFixed(1)} mm).",
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
          const SizedBox(height: 18),
          ...latest.map((w) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: Color(0xFF5B4BFF),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Dengue Surveillance Record",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF172033),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Rainfall: ${((w["rainfall_mm"] ?? 0) as num).toStringAsFixed(1)} mm • Humidity: ${((w["humidity_pct"] ?? 0) as num).toStringAsFixed(1)}%",
                          style: const TextStyle(
                            color: Color(0xFF5F6B7A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${w["dengue_cases"] ?? "-"} cases",
                    style: const TextStyle(
                      color: Color(0xFFFF2F6D),
                      fontWeight: FontWeight.w900,
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
                  const Text(
                    "Weekly Dengue Case Trend",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 260,
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2000,
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
                              reservedSize: 42,
                              interval: 2000,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  "${(value / 1000).toStringAsFixed(0)}K",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF98A1B2),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF98A1B2),
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
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF172033),
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  "${spot.y.toInt()} cases",
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              }).toList();
                            },
                          ),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5B4BFF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF8A94A6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
