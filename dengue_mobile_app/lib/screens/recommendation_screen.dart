import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final TextEditingController casesController = TextEditingController();

  String? selectedArea;
  double rainfall = 15.0;
  double temperature = 28.0;

  bool isLoading = false;
  Map<String, dynamic>? result;
  String? errorMessage;

  bool isAreaRiskLoading = false;
  Map<String, dynamic>? areaRiskResult;
  String? areaRiskError;

  bool isWeatherLoading = false;
  Map<String, dynamic>? weatherResult;
  String? weatherError;

  List<String> areas = [];
  bool isAreasLoading = true;
  String? areasError;

  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);
  static const Color red = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    loadMohAreas();
  }

  @override
  void dispose() {
    casesController.dispose();
    super.dispose();
  }

  Future<void> loadMohAreas() async {
    setState(() {
      isAreasLoading = true;
      areasError = null;
    });

    try {
      final loadedAreas = await ApiService.getMohAreas();

      if (!mounted) return;

      setState(() {
        areas = loadedAreas;
        isAreasLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        areasError = 'Cannot load MOH areas. Please try again.';
        isAreasLoading = false;
      });
    }
  }

  Future<void> loadAreaProxyRisk(String area) async {
    setState(() {
      isAreaRiskLoading = true;
      areaRiskResult = null;
      areaRiskError = null;
    });

    try {
      final response = await ApiService.getAreaProxyRisk(
        area: area,
        year: DateTime.now().year,
        week: 1,
      );

      if (!mounted) return;

      setState(() {
        areaRiskResult = response;
        isAreaRiskLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        areaRiskError =
            'Area proxy-risk preview is currently unavailable for $area.';
        isAreaRiskLoading = false;
      });
    }
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> loadAreaWeather(String area) async {
    setState(() {
      isWeatherLoading = true;
      weatherResult = null;
      weatherError = null;
    });

    try {
      final response = await ApiService.getAreaWeather(area: area);

      final loadedRainfall = _toDouble(response['rainfall'], rainfall);
      final loadedTemperature = _toDouble(response['temperature'], temperature);

      if (!mounted) return;

      setState(() {
        weatherResult = response;

        // Keeps slider values inside their valid ranges.
        rainfall = loadedRainfall.clamp(0.0, 150.0).toDouble();
        temperature = loadedTemperature.clamp(20.0, 40.0).toDouble();

        isWeatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        weatherError =
            'Weather context is currently unavailable for $area. '
            'You can enter values manually.';
        isWeatherLoading = false;
      });
    }
  }

  Future<void> getRecommendation() async {
    if (selectedArea == null) {
      setState(() {
        errorMessage = 'Please select an MOH area.';
      });
      return;
    }

    if (casesController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter dengue cases.';
      });
      return;
    }

    final parsedCases = int.tryParse(casesController.text.trim());

    if (parsedCases == null || parsedCases <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid dengue case count greater than 0.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      result = null;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getRecommendation(
        area: selectedArea!,
        cases: parsedCases,
        rainfall: rainfall,
        temperature: temperature,
      );

      if (!mounted) return;

      setState(() {
        result = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Color riskColor(String risk) {
    if (risk == 'HIGH') return Colors.red;
    if (risk == 'MEDIUM') return Colors.orange;
    return Colors.green;
  }

  IconData riskIcon(String risk) {
    if (risk == 'HIGH') return Icons.warning_amber_rounded;
    if (risk == 'MEDIUM') return Icons.error_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  String getRiskInterpretation(String risk) {
    if (result != null && result!['risk_interpretation'] != null) {
      return result!['risk_interpretation'].toString();
    }

    if (risk == 'HIGH') {
      return 'Urgent dengue intervention is required. PHI warning is triggered for this high-risk situation.';
    }

    if (risk == 'MEDIUM') {
      return 'Moderate dengue risk detected. Preventive actions are recommended before the situation becomes critical.';
    }

    return 'The situation is currently stable. Continue monitoring the area regularly.';
  }

  String getActionExplanation(String risk, String action) {
    if (result != null && result!['recommendation_explanation'] != null) {
      return result!['recommendation_explanation'].toString();
    }

    if (risk == 'HIGH') {
      return 'High dengue cases with rainfall and temperature conditions indicate increased mosquito breeding risk. Therefore, urgent intervention such as $action is recommended.';
    }

    if (risk == 'MEDIUM') {
      return 'The area shows moderate dengue risk. The recommended action helps reduce possible outbreak growth at an early stage.';
    }

    return 'The current risk level is low. The recommended action focuses on monitoring and prevention.';
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = (result?['risk_level'] ?? 'LOW').toString();
    final recommendations = result?['recommendations'] as List?;
    final email = result?['email'];
    final topAction = result?['top_action'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Risk Assessment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topInfoCard(),
            const SizedBox(height: 18),
            _inputCard(),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: isLoading ? null : getRecommendation,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(isLoading ? 'ANALYZING...' : 'GET RECOMMENDATION'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _messageCard(
                icon: Icons.error_outline,
                color: Colors.red,
                message: errorMessage!,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 22),
              _riskCard(riskLevel),
              const SizedBox(height: 12),
              _messageCard(
                icon: Icons.insights_rounded,
                color: riskColor(riskLevel),
                titleText: 'Risk Interpretation',
                message: getRiskInterpretation(riskLevel),
              ),
              const SizedBox(height: 18),
              if (topAction != null)
                _messageCard(
                  icon: Icons.star_rounded,
                  color: Colors.amber,
                  titleText: 'Top Recommended Action',
                  message: topAction.toString(),
                ),
              const SizedBox(height: 18),
              const Text(
                'Recommended Interventions',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: title,
                ),
              ),
              const SizedBox(height: 12),
              if (recommendations != null)
                ...recommendations.map(_recommendationTile),
              const SizedBox(height: 14),
              if (recommendations != null && recommendations.isNotEmpty)
                _messageCard(
                  icon: Icons.lightbulb_outline_rounded,
                  color: Colors.lightBlue,
                  titleText: 'Why this action?',
                  message: getActionExplanation(
                    riskLevel,
                    recommendations.first['action'].toString(),
                  ),
                ),
              const SizedBox(height: 14),
              if (riskLevel == 'HIGH')
                _messageCard(
                  icon: Icons.mark_email_read_rounded,
                  color: email != null && email['sent'] == true
                      ? Colors.green
                      : Colors.orange,
                  titleText: 'PHI Warning Email',
                  message: email != null && email['sent'] == true
                      ? '✅ ${email['message']}'
                      : '⚠️ ${email?['message'] ?? 'Email not sent'}',
                )
              else
                _messageCard(
                  icon: Icons.info_outline_rounded,
                  color: Colors.green,
                  titleText: 'PHI Email',
                  message: 'Email is sent only when the calculated risk is HIGH.',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE8F0FF),
            child: Icon(Icons.psychology_alt_rounded, color: red, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Select an MOH area, review the available dataset context, and enter the current dengue case count for an intervention recommendation.',
              style: TextStyle(color: sub, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Card(
      color: card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MOH Area',
              style: TextStyle(fontWeight: FontWeight.bold, color: title),
            ),
            const SizedBox(height: 8),
            if (isAreasLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Loading MOH areas...'),
                  ],
                ),
              )
            else if (areasError != null)
              _messageCard(
                icon: Icons.error_outline_rounded,
                color: Colors.red,
                titleText: 'MOH Areas Unavailable',
                message: areasError!,
              )
            else if (areas.isEmpty)
              _messageCard(
                icon: Icons.info_outline_rounded,
                color: Colors.orange,
                titleText: 'No MOH Areas',
                message: 'No MOH areas are available in the database.',
              )
            else
              DropdownButtonFormField<String>(
                value: selectedArea,
                hint: const Text('Select MOH area'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                items: areas
                    .map(
                      (area) => DropdownMenuItem(
                        value: area,
                        child: Text(area),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    selectedArea = value;
                    result = null;
                    errorMessage = null;
                  });

                  loadAreaProxyRisk(value);
                  loadAreaWeather(value);
                },
              ),
            const SizedBox(height: 12),
            _areaRiskPreviewCard(),
            const SizedBox(height: 12),
            _weatherContextCard(),
            const SizedBox(height: 18),
            const Text(
              'Weekly Reported Dengue Cases',
              style: TextStyle(fontWeight: FontWeight.bold, color: title),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: casesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Example: 25',
                prefixIcon: Icon(Icons.bug_report_rounded),
              ),
            ),
            const SizedBox(height: 22),
            _sliderBlock(
              titleText: 'Rainfall',
              value: rainfall,
              unit: 'mm',
              min: 0,
              max: 150,
              divisions: 150,
              icon: Icons.water_drop_rounded,
              onChanged: (value) => setState(() => rainfall = value),
            ),
            const SizedBox(height: 12),
            _sliderBlock(
              titleText: 'Temperature',
              value: temperature,
              unit: '°C',
              min: 20,
              max: 40,
              divisions: 40,
              icon: Icons.thermostat_rounded,
              onChanged: (value) => setState(() => temperature = value),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can adjust the rainfall and temperature values before analysis.',
              style: TextStyle(color: sub, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaRiskPreviewCard() {
    if (isAreaRiskLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading historical area-risk context...'),
          ],
        ),
      );
    }

    if (areaRiskError != null) {
      return _messageCard(
        icon: Icons.info_outline_rounded,
        color: Colors.blueGrey,
        titleText: 'Historical Area Risk Context',
        message: areaRiskError!,
      );
    }

    if (areaRiskResult == null) {
      return _messageCard(
        icon: Icons.insights_rounded,
        color: Colors.blue,
        titleText: 'Historical Area Risk Context',
        message: 'Select an MOH area to load its model-based historical risk context.',
      );
    }

    final risk =
        (areaRiskResult!['predicted_area_risk_level'] ?? 'Unknown')
            .toString()
            .toUpperCase();

    final probabilities =
        Map<String, dynamic>.from(areaRiskResult!['probabilities'] ?? {});

    final high = probabilities['High'] ?? probabilities['HIGH'] ?? 0;
    final medium = probabilities['Medium'] ?? probabilities['MEDIUM'] ?? 0;
    final low = probabilities['Low'] ?? probabilities['LOW'] ?? 0;
    final color = riskColor(risk);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Historical Area Risk Context',
                  style: TextStyle(fontWeight: FontWeight.bold, color: title),
                ),
              ),
              Text(
                risk,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'High: $high%   Medium: $medium%   Low: $low%',
            style: const TextStyle(color: sub, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'This is model-based historical context, not the current calculated risk.',
            style: TextStyle(color: sub, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weatherContextCard() {
    if (isWeatherLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading area weather context...'),
          ],
        ),
      );
    }

    if (weatherError != null) {
      return _messageCard(
        icon: Icons.cloud_off_rounded,
        color: Colors.orange,
        titleText: 'Weather Context Unavailable',
        message: weatherError!,
      );
    }

    if (weatherResult == null) {
      return _messageCard(
        icon: Icons.cloud_outlined,
        color: Colors.blue,
        titleText: 'Latest Dataset Weather Context',
        message: 'Select an MOH area to auto-fill available rainfall and temperature context.',
      );
    }

    final source =
        weatherResult!['source']?.toString() ?? 'Project dataset context';
    final updatedAt = weatherResult!['updated_at']?.toString() ?? 'Not available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Latest Dataset Weather Context loaded. Rainfall and temperature were auto-filled below.',
              style: TextStyle(
                color: title,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderBlock({
    required String titleText,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required IconData icon,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titleText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: title,
                  ),
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  color: red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _riskCard(String risk) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor(risk).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: riskColor(risk).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(riskIcon(risk), color: riskColor(risk), size: 48),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Risk Level',
                  style: TextStyle(color: sub),
                ),
                Text(
                  risk,
                  style: TextStyle(
                    color: riskColor(risk),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendationTile(dynamic item) {
    return Card(
      color: card,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: red.withValues(alpha: 0.12),
          child: Text(
            '${item['rank']}',
            style: const TextStyle(
              color: red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          item['action'].toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: title,
          ),
        ),
        subtitle: const Text(
          'RL agent recommended action',
          style: TextStyle(color: sub),
        ),
        trailing: Text(
          '${item['confidence']}%',
          style: const TextStyle(
            color: red,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color color,
    required String message,
    String? titleText,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titleText == null ? message : '$titleText\n$message',
              style: const TextStyle(height: 1.4, color: title),
            ),
          ),
        ],
      ),
    );
  }
}