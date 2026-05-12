import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_components.dart';

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  final week = TextEditingController(text: "1");
  final month = TextEditingController(text: "1");
  final tempMax = TextEditingController(text: "32");
  final tempMin = TextEditingController(text: "24");
  final tempMean = TextEditingController(text: "28");
  final humidity = TextEditingController(text: "78");
  final rainfall = TextEditingController(text: "70");
  final wind = TextEditingController(text: "5");
  final cloud = TextEditingController(text: "50");
  final visibility = TextEditingController(text: "4");
  final uvindex = TextEditingController(text: "7");
  final rainfallChange = TextEditingController(text: "30");
  final humidityChange = TextEditingController(text: "5");
  final temperatureChange = TextEditingController(text: "0");
  final windChange = TextEditingController(text: "0");

  Map<String, dynamic>? result;
  bool isLoading = false;

  double _double(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 1;

  Future<void> simulate() async {
    setState(() {
      isLoading = true;
      result = null;
    });

    final payload = {
      "year": 2024,
      "week": _int(week),
      "month": _int(month),
      "temp_max_c": _double(tempMax),
      "temp_min_c": _double(tempMin),
      "temp_mean_c": _double(tempMean),
      "humidity_pct": _double(humidity),
      "rainfall_mm": _double(rainfall),
      "wind_speed_kmh": _double(wind),
      "cloudcover": _double(cloud),
      "visibility": _double(visibility),
      "uvindex": _double(uvindex),
      "rainfall_change": _double(rainfallChange),
      "humidity_change": _double(humidityChange),
      "temperature_change": _double(temperatureChange),
      "wind_change": _double(windChange),
    };

    final response = await ApiService.simulateRisk(payload);

    setState(() {
      result = response;
      isLoading = false;
    });
  }

  Widget input(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: kPrimary),
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE7DFF4))),
      ),
    );
  }

  Color riskColor(String? risk) {
    if (risk == "High") return kRed;
    if (risk == "Medium") return kOrange;
    if (risk == "Low") return kGreen;
    return kMuted;
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = result != null && result?["error"] != true;

    return Column(
      children: [
        AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Risk Simulator"), SizedBox(height: 2), Text("Counterfactual dengue risk analysis", style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))])),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle("Current Conditions", subtitle: "Enter current weather and time values."),
              Row(children: [Expanded(child: input("Week", week, Icons.calendar_month)), const SizedBox(width: 10), Expanded(child: input("Month", month, Icons.date_range))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: input("Temp Max", tempMax, Icons.thermostat)), const SizedBox(width: 10), Expanded(child: input("Temp Min", tempMin, Icons.thermostat_outlined))]),
              const SizedBox(height: 10),
              input("Mean Temperature", tempMean, Icons.device_thermostat),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: input("Humidity %", humidity, Icons.water_drop)), const SizedBox(width: 10), Expanded(child: input("Rainfall mm", rainfall, Icons.cloudy_snowing))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: input("Wind km/h", wind, Icons.air)), const SizedBox(width: 10), Expanded(child: input("UV Index", uvindex, Icons.wb_sunny))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: input("Cloud cover", cloud, Icons.cloud)), const SizedBox(width: 10), Expanded(child: input("Visibility", visibility, Icons.visibility))]),
              const SectionTitle("What-if Changes", subtitle: "Apply weather changes to simulate future dengue risk."),
              Row(children: [Expanded(child: input("Rainfall + / -", rainfallChange, Icons.add_chart)), const SizedBox(width: 10), Expanded(child: input("Humidity + / -", humidityChange, Icons.opacity))]),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: input("Temperature + / -", temperatureChange, Icons.thermostat_auto)), const SizedBox(width: 10), Expanded(child: input("Wind + / -", windChange, Icons.air_rounded))]),
              const SizedBox(height: 18),
              GradientButton(text: "Simulate Risk", icon: Icons.auto_graph, onPressed: simulate),
              const SizedBox(height: 22),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              if (result?["error"] == true) SoftCard(child: Text(result?["message"] ?? "Simulation failed", style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
              if (hasResult) ...[
                const SectionTitle("Simulation Result"),
                SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: _RiskBox(title: "Original Risk", risk: result?["original_risk"], confidence: result?["original_confidence"], color: riskColor(result?["original_risk"]))),
                    const SizedBox(width: 10),
                    Expanded(child: _RiskBox(title: "Simulated Risk", risk: result?["simulated_risk"], confidence: result?["simulated_confidence"], color: riskColor(result?["simulated_risk"]))),
                  ]),
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: kPrimary.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.trending_up, color: kPrimary), const SizedBox(width: 10), Expanded(child: Text("Risk Change: ${result?["risk_change"]}", style: const TextStyle(fontWeight: FontWeight.w900, color: kInk)))])),
                  const SizedBox(height: 16),
                  const Text("Main Reasons", style: TextStyle(fontWeight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 8),
                  ...(result?["main_reasons"] as List).map((reason) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, size: 18, color: kGreen), const SizedBox(width: 8), Expanded(child: Text(reason, style: const TextStyle(color: kMuted)))]))),
                  const SizedBox(height: 14),
                  const Text("Recommendation", style: TextStyle(fontWeight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 8),
                  Text(result?["recommendation"] ?? "", style: const TextStyle(color: kMuted)),
                ])),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _RiskBox extends StatelessWidget {
  final String title;
  final String? risk;
  final dynamic confidence;
  final Color color;

  const _RiskBox({required this.title, required this.risk, required this.confidence, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        Text(title, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(risk ?? "N/A", style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(confidence == null ? "Confidence N/A" : "Confidence $confidence%", style: const TextStyle(color: kMuted, fontSize: 11)),
      ]),
    );
  }
}
