import 'package:flutter/material.dart';
import '../services/xai_api_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RiskMapScreen extends StatefulWidget {
  const RiskMapScreen({super.key});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  bool loading = true;
  List<dynamic> areas = [];
  Map<String, dynamic>? selectedArea;
  String? errorMessage;

  int? predictionYear;
  int? predictionWeek;

  // Canonical MOH-area names used by the deployed backend.
  final Map<String, LatLng> areaCoordinates = {
    "CMC": const LatLng(6.9271, 79.8612),
    "Dehiwala": const LatLng(6.8517, 79.8657),
    "Hanwella": const LatLng(6.9090, 80.0830),
    "Homagama": const LatLng(6.8440, 80.0030),
    "Kaduwela": const LatLng(6.9300, 79.9820),
    "Kesbewa": const LatLng(6.7800, 79.9300),
    "Kolonnawa": const LatLng(6.9330, 79.8950),
    "Maharagama": const LatLng(6.8480, 79.9260),
    "Moratuwa": const LatLng(6.7730, 79.8820),
    "Padukka": const LatLng(6.8410, 80.0910),
  };

  @override
  void initState() {
    super.initState();
    loadMap();
  }

  Future<void> loadMap() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
        selectedArea = null;
      });
    }

    try {
      // ---------------------------------------------------------
      // 1. Resolve year/week automatically.
      //    Prefer the deployed dashboard context.
      // ---------------------------------------------------------
      int year;
      int week;

      try {
        final dashboard = await ApiService.dashboard();

        year = _toInt(dashboard["year"]) ?? DateTime.now().year;
        week = _toInt(dashboard["week"]) ?? _isoWeekNumber(DateTime.now());
      } catch (_) {
        final now = DateTime.now();

        year = now.year;
        week = _isoWeekNumber(now);
      }

      predictionYear = year;
      predictionWeek = week;

      // ---------------------------------------------------------
      // 2. Get canonical MOH-area names from backend.
      // ---------------------------------------------------------
      final areaNames = await ApiService.mohRisk();

      debugPrint("========== MOH AREA NAMES ==========");
      debugPrint(areaNames.toString());
      debugPrint("Total areas: ${areaNames.length}");
      debugPrint("Prediction context: $year W$week");
      debugPrint("====================================");

      final List<Map<String, dynamic>> loadedAreas = [];

      // ---------------------------------------------------------
      // 3. Request area proxy risk for every canonical area.
      // ---------------------------------------------------------
      for (final item in areaNames) {
        final areaName = _extractAreaName(item);

        if (areaName == null || areaName.isEmpty) {
          debugPrint("Invalid MOH area item: $item");
          continue;
        }

        final coordinates = areaCoordinates[areaName];

        if (coordinates == null) {
          debugPrint(
            "No map coordinates configured for canonical area: $areaName",
          );
          continue;
        }

        try {
          final prediction = await ApiService.predictAreaRisk(
            area: areaName,
            year: year,
            week: week,
          );

          final probabilities = _extractProbabilities(prediction);

          final dataContext = prediction["data_context"];

          String? confidenceLevel;

          if (dataContext is Map) {
            confidenceLevel =
                dataContext["confidence_level"]?.toString();
          }

          loadedAreas.add({
            "name": areaName,
            "risk":
                prediction["predicted_area_risk_level"]?.toString() ??
                "Unknown",
            "lat": coordinates.latitude,
            "lng": coordinates.longitude,
            "probabilities": probabilities,
            "model_used": prediction["model_used"],
            "validation": prediction["validation"],
            "important_note": prediction["important_note"],
            "confidence_level": confidenceLevel,
            "year": year,
            "week": week,
          });

          debugPrint(
            "$areaName → "
            "${prediction["predicted_area_risk_level"]}",
          );
        } catch (e) {
          // One failed area should not break the entire map.
          debugPrint(
            "Prediction failed for $areaName: $e",
          );
        }
      }

      debugPrint("========== FINAL MAP DATA ==========");
      debugPrint(loadedAreas.toString());
      debugPrint("====================================");

      if (!mounted) return;

      setState(() {
        areas = loadedAreas;
        loading = false;

        if (loadedAreas.isEmpty) {
          errorMessage =
              "MOH-area risk data could not be loaded. Please try again.";
        }
      });
    } catch (e) {
      debugPrint("========== MAP ERROR ==========");
      debugPrint(e.toString());
      debugPrint("===============================");

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            "Unable to load the MOH risk map. Please check the connection and try again.";
      });
    }
  }

  String? _extractAreaName(dynamic item) {
    if (item is String) {
      return item.trim();
    }

    if (item is Map) {
      final value =
          item["name"] ??
          item["area"] ??
          item["moh_area"] ??
          item["moh_area_name"];

      return value?.toString().trim();
    }

    return item?.toString().trim();
  }

  Map<String, dynamic> _extractProbabilities(
    Map<String, dynamic> prediction,
  ) {
    final rawProbabilities = prediction["probabilities"];

    if (rawProbabilities is Map) {
      return {
        "High": _normalizeProbability(
          rawProbabilities["High"] ??
              rawProbabilities["high"],
        ),
        "Medium": _normalizeProbability(
          rawProbabilities["Medium"] ??
              rawProbabilities["medium"],
        ),
        "Low": _normalizeProbability(
          rawProbabilities["Low"] ??
              rawProbabilities["low"],
        ),
      };
    }

    return {
      "High": _normalizeProbability(
        prediction["high_probability"] ??
            prediction["highProbability"] ??
            prediction["probability_high"],
      ),
      "Medium": _normalizeProbability(
        prediction["medium_probability"] ??
            prediction["mediumProbability"] ??
            prediction["probability_medium"],
      ),
      "Low": _normalizeProbability(
        prediction["low_probability"] ??
            prediction["lowProbability"] ??
            prediction["probability_low"],
      ),
    };
  }

  double _normalizeProbability(dynamic value) {
    if (value is num) {
      final number = value.toDouble();

      if (number >= 0 && number <= 1) {
        return number * 100;
      }

      return number.clamp(0.0, 100.0);
    }

    final parsed = double.tryParse(value?.toString() ?? "");

    if (parsed == null) {
      return 0.0;
    }

    if (parsed >= 0 && parsed <= 1) {
      return parsed * 100;
    }

    return parsed.clamp(0.0, 100.0);
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? "");
  }

  int _isoWeekNumber(DateTime date) {
    final normalized = DateTime.utc(
      date.year,
      date.month,
      date.day,
    );

    final thursday = normalized.add(
      Duration(days: 4 - normalized.weekday),
    );

    final firstThursday = DateTime.utc(
      thursday.year,
      1,
      4,
    );

    final firstWeekThursday = firstThursday.add(
      Duration(days: 4 - firstThursday.weekday),
    );

    return 1 +
        thursday.difference(firstWeekThursday).inDays ~/ 7;
  }

  Color riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case "high":
        return const Color(0xFFFF477E);

      case "medium":
        return const Color(0xFFFFA726);

      case "low":
        return const Color(0xFF18A982);

      default:
        return const Color(0xFF7E8A9D);
    }
  }

  String riskMessage(String risk) {
    switch (risk.toLowerCase()) {
      case "high":
        return "High surveillance priority. Increase field inspections and mosquito breeding-site control.";

      case "medium":
        return "Moderate surveillance priority. Continue weekly monitoring and community awareness.";

      case "low":
        return "Routine surveillance priority. Maintain dengue prevention activities.";

      default:
        return "Area risk information is currently unavailable.";
    }
  }

  Widget mohMarker(Map<String, dynamic> area) {
    final risk = area["risk"].toString();
    final color = riskColor(risk);
    final isSelected =
        selectedArea?["name"] == area["name"];

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedArea = area;
        });
      },
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSelected ? 28 : 21,
          height: isSelected ? 28 : 21,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget legendItem(
    String label,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
      ],
    );
  }

  Widget areaInfoCard() {
    final contextText =
        predictionYear != null && predictionWeek != null
            ? "Year $predictionYear • Week $predictionWeek"
            : "Latest available prediction context";

    return Positioned(
      top: 18,
      left: 18,
      right: 18,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on,
              color: Color(0xFF5B4BFF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Colombo District MOH Surveillance Map",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contextText,
                    style: const TextStyle(
                      color: Color(0xFF7E8A9D),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

  Widget selectedAreaPopup() {
    if (selectedArea == null) {
      return const SizedBox.shrink();
    }

    final name =
        selectedArea!["name"]?.toString() ?? "Unknown";

    final risk =
        selectedArea!["risk"]?.toString() ?? "Unknown";

    final color = riskColor(risk);

    final rawProbabilities =
        selectedArea!["probabilities"];

    final probabilities =
        rawProbabilities is Map
            ? Map<String, dynamic>.from(
                rawProbabilities,
              )
            : <String, dynamic>{};

    final high = _normalizeProbability(
      probabilities["High"],
    );

    final medium = _normalizeProbability(
      probabilities["Medium"],
    );

    final low = _normalizeProbability(
      probabilities["Low"],
    );

    final year =
        selectedArea!["year"]?.toString();

    final week =
        selectedArea!["week"]?.toString();

    return Positioned(
      left: 18,
      right: 18,
      bottom: 92,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: color.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172033),
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "MOH area proxy risk assessment",
                        style: TextStyle(
                          color: Color(0xFF8A94A6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (year != null &&
                          week != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          "Year $year • Week $week",
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 9.5,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedArea = null;
                    });
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF7E8A9D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color:
                        color.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$risk Risk",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: Color(0xFF7E8A9D),
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    "ML proxy/context prediction",
                    style: TextStyle(
                      color: Color(0xFF7E8A9D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              riskMessage(risk),
              style: const TextStyle(
                color: Color(0xFF5F6B7A),
                height: 1.4,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Risk Probability Breakdown",
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            probabilityRow(
              "High",
              high,
              const Color(0xFFFF477E),
            ),
            const SizedBox(height: 10),
            probabilityRow(
              "Medium",
              medium,
              const Color(0xFFFFA726),
            ),
            const SizedBox(height: 10),
            probabilityRow(
              "Low",
              low,
              const Color(0xFF18A982),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius:
                    BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF5B4BFF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedArea!["model_used"]
                              ?.toString() ??
                          "ML model-based area proxy risk assessment",
                      style: const TextStyle(
                        color: Color(0xFF5F6B7A),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedArea!["important_note"] !=
                null) ...[
              const SizedBox(height: 12),
              Text(
                selectedArea!["important_note"]
                    .toString(),
                style: const TextStyle(
                  color: Color(0xFF7A879A),
                  fontSize: 9.5,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget probabilityRow(
    String label,
    double value,
    Color color,
  ) {
    final safeValue =
        value.clamp(0.0, 100.0);

    final percentage = safeValue / 100;

    return Column(
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF65758E),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              "${safeValue.toStringAsFixed(1)}%",
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius:
              BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 7,
            color: color,
            backgroundColor:
                color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> mapSource() {
    return areas
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (area) =>
              Map<String, dynamic>.from(area),
        )
        .toList();
  }

  List<Marker> buildMarkers() {
    return mapSource().map<Marker>((area) {
      final latValue = area["lat"];
      final lngValue = area["lng"];

      if (latValue is! num ||
          lngValue is! num) {
        return const Marker(
          point: LatLng(6.9010, 79.8700),
          width: 0,
          height: 0,
          child: SizedBox.shrink(),
        );
      }

      return Marker(
        point: LatLng(
          latValue.toDouble(),
          lngValue.toDouble(),
        ),
        width: 44,
        height: 44,
        child: mohMarker(area),
      );
    }).toList();
  }

  Widget _errorView() {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("MOH Risk Map"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 56,
                color: Color(0xFF7E8A9D),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage ??
                    "Risk map data is unavailable.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF65758E),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: loadMap,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text("Try Again"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null &&
        areas.isEmpty) {
      return _errorView();
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFFF5F7FB),
        foregroundColor:
            const Color(0xFF172033),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
            Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFEFF4FF),
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.map,
                color: Color(0xFF5B4BFF),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    "MOH Risk Map",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.w900,
                      color:
                          Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Colombo District area proxy context",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: loadMap,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter:
                  const LatLng(
                6.8700,
                79.9300,
              ),
              initialZoom: 10.8,
              minZoom: 9.5,
              maxZoom: 16,
              onTap: (_, __) {
                setState(() {
                  selectedArea = null;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.example.dengue_app',
              ),
              MarkerLayer(
                markers: buildMarkers(),
              ),
            ],
          ),
          areaInfoCard(),
          selectedAreaPopup(),
          Positioned(
            bottom: 22,
            left: 18,
            right: 18,
            child: Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white
                    .withValues(alpha: 0.96),
                borderRadius:
                    BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset:
                        const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                children: [
                  legendItem(
                    "High",
                    const Color(0xFFFF2F6D),
                  ),
                  legendItem(
                    "Medium",
                    Colors.orange,
                  ),
                  legendItem(
                    "Low",
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}