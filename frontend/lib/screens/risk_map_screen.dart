import 'package:flutter/material.dart';
import '../services/api_service.dart';
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

  final Map<String, LatLng> areaCoordinates = {
    "Avissawella": const LatLng(6.9540, 80.2100),
    "Colombo": const LatLng(6.9271, 79.8612),
    "Dehiwala": const LatLng(6.8517, 79.8657),
    "Homagama": const LatLng(6.8440, 80.0030),
    "Kaduwela": const LatLng(6.9300, 79.9820),
    "Kesbewa": const LatLng(6.7800, 79.9300),
    "Kolonnawa": const LatLng(6.9330, 79.8950),
    "Kotte": const LatLng(6.8905, 79.9014),
    "Maharagama": const LatLng(6.8480, 79.9260),
    "Moratuwa": const LatLng(6.7730, 79.8820),
  };

  @override
  void initState() {
    super.initState();
    loadMap();
  }

  Future<void> loadMap() async {
    try {
      // Get the 10 MOH area names
      final areaNames = await ApiService.mohRisk();

      debugPrint("========== MOH AREA NAMES ==========");
      debugPrint(areaNames.toString());
      debugPrint("Total areas: ${areaNames.length}");
      debugPrint("====================================");

      final List<Map<String, dynamic>> loadedAreas = [];

      final Map<String, String> areaNameMapping = {
        "Colombo": "CMC",
      };

      // Get risk prediction for each area
      for (final item in areaNames) {
        final String areaName = item.toString();

        final String apiAreaName = areaNameMapping[areaName] ?? areaName;

        try {
          final prediction = await ApiService.predictAreaRisk(
            area: apiAreaName,
            year: 2026,
            week: 13,
          );

          final coordinates = areaCoordinates[areaName];

          if (coordinates == null) {
            debugPrint(
              "No coordinates found for: $areaName",
            );
            continue;
          }

          loadedAreas.add({
            "name": areaName,
            "risk":
                prediction["predicted_area_risk_level"]?.toString() ?? "Low",
            "lat": coordinates.latitude,
            "lng": coordinates.longitude,
            "probabilities": prediction["probabilities"],
            "model_used": prediction["model_used"],
            "validation": prediction["validation"],
            "important_note": prediction["important_note"],
            "confidence_level": prediction["data_context"]?["confidence_level"],
          });

          debugPrint(
            "$areaName → "
            "${prediction["predicted_area_risk_level"]}",
          );
        } catch (e) {
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
      });
    } catch (e) {
      debugPrint("========== MAP ERROR ==========");
      debugPrint(e.toString());
      debugPrint("===============================");

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
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
    if (risk == "High") {
      return "High surveillance priority. Increase field inspections and mosquito breeding-site control.";
    }
    if (risk == "Medium") {
      return "Moderate surveillance priority. Continue weekly monitoring and community awareness.";
    }
    return "Routine surveillance priority. Maintain dengue prevention activities.";
  }

  Widget mohMarker(Map<String, dynamic> area) {
    final risk = area["risk"].toString();
    final color = riskColor(risk);

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedArea = area;
        });
      },
      child: Center(
        child: Container(
          width: selectedArea?["name"] == area["name"] ? 26 : 20,
          height: selectedArea?["name"] == area["name"] ? 26 : 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
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

  Widget legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        child: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF5B4BFF)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Colombo District MOH Surveillance Map",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF172033),
                ),
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

    final name = selectedArea!["name"].toString();
    final risk = selectedArea!["risk"].toString();
    final color = riskColor(risk);

    final probabilities =
        selectedArea!["probabilities"] as Map<String, dynamic>? ?? {};

    final high = (probabilities["High"] as num?)?.toDouble() ?? 0.0;

    final medium = (probabilities["Medium"] as num?)?.toDouble() ?? 0.0;

    final low = (probabilities["Low"] as num?)?.toDouble() ?? 0.0;

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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        "MOH area risk assessment",
                        style: TextStyle(
                          color: Color(0xFF8A94A6),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
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
                const Text(
                  "AI model prediction",
                  style: TextStyle(
                    color: Color(0xFF7E8A9D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF5B4BFF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedArea!["model_used"]?.toString() ??
                          "AI model-based risk assessment",
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
    final percentage = value.clamp(0.0, 100.0) / 100;

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
              "${value.toStringAsFixed(1)}%",
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
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> mapSource() {
    return areas
        .whereType<Map>()
        .map<Map<String, dynamic>>(
          (area) => Map<String, dynamic>.from(area),
        )
        .toList();
  }

  List<Marker> buildMarkers() {
    return mapSource().map<Marker>((area) {
      final latValue = area["lat"];
      final lngValue = area["lng"];

      if (latValue is! num || lngValue is! num) {
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.map, color: Color(0xFF5B4BFF)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "MOH Risk Map",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF172033),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Colombo district surveillance",
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
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(6.9010, 79.8700),
              initialZoom: 12.4,
              minZoom: 11,
              maxZoom: 16,
              onTap: (_, __) {
                setState(() {
                  selectedArea = null;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dengue_app',
              ),
              MarkerLayer(markers: buildMarkers()),
            ],
          ),
          areaInfoCard(),
          selectedAreaPopup(),
          Positioned(
            bottom: 22,
            left: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  legendItem("High", const Color(0xFFFF2F6D)),
                  legendItem("Medium", Colors.orange),
                  legendItem("Low", Colors.green),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
