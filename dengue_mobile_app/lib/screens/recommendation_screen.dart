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

  String selectedArea = 'Colombo';
  double rainfall = 15.0;
  double temperature = 28.0;

  bool isLoading = false;
  Map<String, dynamic>? result;
  String? errorMessage;

  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);
  static const Color red = Color(0xFFE53935);

  final List<String> areas = [
    'Colombo',
    'Dehiwala',
    'Moratuwa',
    'Kotte',
    'Kaduwela',
    'Kesbewa',
    'Kolonnawa',
    'Maharagama',
    'Padukka',
    'Seethawaka',
    'Homagama',
    'Avissawella',
  ];

  Future<void> getRecommendation() async {
    if (casesController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter dengue cases.';
      });
      return;
    }

    final int? parsedCases = int.tryParse(casesController.text.trim());

    if (parsedCases == null || parsedCases <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid dengue case count greater than 0.';
      });
      return;
    }

    final int cases = parsedCases;

    setState(() {
      isLoading = true;
      result = null;
      errorMessage = null;
    });

    try {
      final response = await ApiService.getRecommendation(
        area: selectedArea,
        cases: cases,
        rainfall: rainfall,
        temperature: temperature,
      );

      setState(() {
        result = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void loadHighRiskSample() {
    setState(() {
      selectedArea = 'Colombo';
      casesController.text = '6000';
      rainfall = 20.0;
      temperature = 28.0;
      result = null;
      errorMessage = null;
    });
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
    } else if (risk == 'MEDIUM') {
      return 'Moderate dengue risk detected. Preventive actions are recommended before the situation becomes critical.';
    } else {
      return 'The situation is currently stable. Continue monitoring the area regularly.';
    }
  }

  String getActionExplanation(String risk, String action) {
    if (result != null && result!['recommendation_explanation'] != null) {
      return result!['recommendation_explanation'].toString();
    }

    if (risk == 'HIGH') {
      return 'High dengue cases with rainfall and temperature conditions indicate increased mosquito breeding risk. Therefore, urgent intervention such as $action is recommended.';
    } else if (risk == 'MEDIUM') {
      return 'The area shows moderate dengue risk. The recommended action helps reduce possible outbreak growth at an early stage.';
    } else {
      return 'The current risk level is low. The recommended action focuses on monitoring and prevention.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final riskLevel = result?['risk_level'];
    final recommendations = result?['recommendations'] as List?;
    final email = result?['email'];
    final topAction = result?['top_action'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('AI Recommendation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topInfoCard(),
            const SizedBox(height: 18),
            _inputCard(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: loadHighRiskSample,
              icon: const Icon(Icons.science_rounded),
              label: const Text(
                'LOAD HIGH RISK SAMPLE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
              label: Text(isLoading ? 'Analyzing...' : 'GET RECOMMENDATION'),
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
                ...recommendations.map((item) => _recommendationTile(item)),
              const SizedBox(height: 14),
              if (recommendations != null && recommendations.isNotEmpty) ...[
                _messageCard(
                  icon: Icons.lightbulb_outline_rounded,
                  color: Colors.lightBlue,
                  titleText: 'Why this action?',
                  message: getActionExplanation(
                    riskLevel,
                    recommendations.first['action'],
                  ),
                ),
                const SizedBox(height: 14),
              ],
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
                  message: 'Email not sent because risk level is not HIGH.',
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
            backgroundColor: Color(0xFFFEE2E2),
            child: Icon(Icons.psychology_alt_rounded, color: red, size: 32),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Enter current dengue situation data. The RL agent will recommend the best intervention action.',
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
            DropdownButtonFormField<String>(
              value: selectedArea,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_rounded),
              ),
              items: areas
                  .map(
                    (area) => DropdownMenuItem(value: area, child: Text(area)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => selectedArea = value!);
              },
            ),
            const SizedBox(height: 18),
            const Text(
              'Dengue Cases',
              style: TextStyle(fontWeight: FontWeight.bold, color: title),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: casesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Example: 6000',
                prefixIcon: Icon(Icons.bug_report_rounded),
              ),
            ),
            const SizedBox(height: 22),
            _sliderBlock(
              titleText: 'Rainfall',
              value: rainfall,
              unit: 'mm',
              min: 0,
              max: 50,
              divisions: 50,
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
          ],
        ),
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
                style: const TextStyle(color: red, fontWeight: FontWeight.bold),
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
                const Text('Detected Risk Level', style: TextStyle(color: sub)),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: red.withValues(alpha: 0.12),
          child: Text(
            '${item['rank']}',
            style: const TextStyle(color: red, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          item['action'],
          style: const TextStyle(fontWeight: FontWeight.bold, color: title),
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
