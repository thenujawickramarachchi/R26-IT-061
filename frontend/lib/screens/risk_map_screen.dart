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

  @override
  void initState() {
    super.initState();
    loadMap();
  }

  Future<void> loadMap() async {
    try {
      final res = await ApiService.mohRisk();
      setState(() {
        areas = res;
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
    if (selectedArea == null) return const SizedBox.shrink();

    final name = selectedArea!["name"].toString();
    final risk = selectedArea!["risk"].toString();
    final cases = selectedArea!["cases"] ?? "-";
    final color = riskColor(risk);

    return Positioned(
      left: 18,
      right: 18,
      bottom: 92,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(Icons.place, color: color),
            ),
            const SizedBox(width: 14),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
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
                          "$risk Risk",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "$cases cases",
                        style: const TextStyle(
                          color: Color(0xFF5F6B7A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    riskMessage(risk),
                    style: const TextStyle(
                      color: Color(0xFF5F6B7A),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> mapSource() {
    if (areas.isNotEmpty) {
      return areas.map<Map<String, dynamic>>((e) {
        return Map<String, dynamic>.from(e as Map);
      }).toList();
    }

    return [
      {
        "name": "Colombo MC",
        "risk": "High",
        "cases": 162,
        "lat": 6.9271,
        "lng": 79.8612,
      },
      {
        "name": "Dehiwala",
        "risk": "High",
        "cases": 128,
        "lat": 6.8760,
        "lng": 79.8757,
      },
      {
        "name": "Maharagama",
        "risk": "Medium",
        "cases": 95,
        "lat": 6.8649,
        "lng": 79.8997,
      },
      {
        "name": "Kaduwela",
        "risk": "Low",
        "cases": 44,
        "lat": 6.9147,
        "lng": 79.9729,
      },
    ];
  }

  List<Marker> buildMarkers() {
    return mapSource().map<Marker>((area) {
      final lat = ((area["lat"] ?? 6.9010) as num).toDouble();
      final lng = ((area["lng"] ?? 79.8700) as num).toDouble();

      return Marker(
        point: LatLng(lat, lng),
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