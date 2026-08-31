import 'package:flutter/material.dart';

import '../services/prediction_api_service.dart';

class ManualPredictionScreen extends StatefulWidget {
  const ManualPredictionScreen({super.key});

  @override
  State<ManualPredictionScreen> createState() =>
      _ManualPredictionScreenState();
}

class _ManualPredictionScreenState extends State<ManualPredictionScreen> {
  static const _primaryColor = Color(0xFF00796B);

  final PredictionApiService api = PredictionApiService();
  final TextEditingController yearController = TextEditingController(text: '2026');
  final TextEditingController weekController = TextEditingController(text: '35');
  final TextEditingController rainfallController = TextEditingController();
  final TextEditingController humidityController = TextEditingController();
  final TextEditingController temperatureController = TextEditingController();
  final TextEditingController lag1Controller = TextEditingController();
  final TextEditingController lag2Controller = TextEditingController();

  int selectedYear = 2026;
  int selectedWeek = 35;

  final List<int> years = List<int>.generate(11, (index) => 2020 + index);
  final List<int> weeks = List<int>.generate(52, (index) => index + 1);

  String selectedArea = 'Colombo';
  final List<String> areas = [
    'Colombo',
    'Dehiwala',
    'Moratuwa',
    'Kaduwela',
    'Homagama',
    'Padukka',
    'Maharagama',
  ];

  bool loading = false;
  bool featuresLoaded = false;
  String riskLevel = '';
  String predictedArea = '';
  int? predictedYear;
  int? predictedWeek;

  @override
  void dispose() {
    yearController.dispose();
    weekController.dispose();
    rainfallController.dispose();
    humidityController.dispose();
    temperatureController.dispose();
    lag1Controller.dispose();
    lag2Controller.dispose();
    super.dispose();
  }

  Future<void> loadFeatures() async {
    final year = int.tryParse(yearController.text);
    final week = int.tryParse(weekController.text);

    if (year == null || week == null) {
      setState(() => riskLevel = 'Enter valid year and week');
      return;
    }

    setState(() {
      loading = true;
      riskLevel = '';
    });

    try {
      final response = await api.getAreaFeatures(
        area: selectedArea,
        year: year,
        week: week,
      );
      final features = response['features'];

      if (!mounted) return;
      setState(() {
        rainfallController.text = features['rainfall_mm'].toString();
        humidityController.text = features['humidity_pct'].toString();
        temperatureController.text = features['temp_mean_c'].toString();
        lag1Controller.text = features['dengue_lag_1'].toString();
        lag2Controller.text = features['dengue_lag_2'].toString();
        featuresLoaded = true;
      });
    } catch (exception) {
      if (mounted) {
        setState(() => riskLevel = exception.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> predict() async {
    final year = int.tryParse(yearController.text);
    final week = int.tryParse(weekController.text);

    if (year == null || week == null) return;

    setState(() {
      loading = true;
      riskLevel = '';
    });

    try {
      final response = await api.predictAreaRisk(
        year: year,
        week: week,
        area: selectedArea,
      );

      if (!mounted) return;
      setState(() {
        riskLevel = response.predictedAreaRiskLevel;
        predictedArea = selectedArea;
        predictedYear = year;
        predictedWeek = week;
      });
    } catch (exception) {
      if (mounted) {
        setState(() => riskLevel = exception.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Color getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  bool get _hasPrediction => ['high', 'medium', 'low'].contains(
        riskLevel.toLowerCase(),
      );

  String getWeekDateRange(int year, int week) {
    final firstDay = DateTime(year, 1, 1);
    final startDate = firstDay.add(Duration(days: (week - 1) * 7));
    final endDate = startDate.add(const Duration(days: 6));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return 'Week $week · '
        '${months[startDate.month - 1]} ${startDate.day} - '
        '${months[endDate.month - 1]} ${endDate.day}';
  }

  Widget _sectionTitle(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(description, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundedField({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E3E1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: _primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _roundedField(
        icon: icon,
        label: label,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      ),
    );
  }

  Widget _periodSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7DBD4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: _primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Prediction Period',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 3),
                Text(
                  getWeekDateRange(selectedYear, selectedWeek),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(riskLevel, style: TextStyle(color: Colors.red.shade900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget resultCard() {
    final color = getRiskColor(riskLevel);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assessment_rounded, color: _primaryColor),
                SizedBox(width: 9),
                Text(
                  'Prediction Result',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$predictedArea · $predictedYear · Week $predictedWeek',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.75)),
              ),
              child: Column(
                children: [
                  Icon(
                    riskLevel.toLowerCase() == 'high'
                        ? Icons.warning_rounded
                        : Icons.health_and_safety_rounded,
                    color: color,
                    size: 50,
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Dengue Area Risk',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${riskLevel.toUpperCase()} RISK',
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        title: const Text('Manual Prediction'),
        centerTitle: true,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: _sectionTitle(
                    Icons.tune_rounded,
                    'Manual Dengue Analysis',
                    'Modify prediction features and analyze dengue risk.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle(
                        Icons.calendar_month_rounded,
                        'Prediction Settings',
                        'Choose the area and period for the prediction.',
                      ),
                      const SizedBox(height: 18),
                      _roundedField(
                        icon: Icons.calendar_today_rounded,
                        label: 'Year',
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          items: years
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year.toString()),
                                ),
                              )
                              .toList(),
                          onChanged: loading
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedYear = value!;
                                    yearController.text = value.toString();
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _roundedField(
                        icon: Icons.date_range_rounded,
                        label: 'Week',
                        child: DropdownButtonFormField<int>(
                          value: selectedWeek,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          items: weeks
                              .map(
                                (week) => DropdownMenuItem<int>(
                                  value: week,
                                  child: Text(
                                    getWeekDateRange(selectedYear, week),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: loading
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedWeek = value!;
                                    weekController.text = value.toString();
                                  });
                                },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _roundedField(
                        icon: Icons.location_on_outlined,
                        label: 'Area',
                        child: DropdownButtonFormField<String>(
                          value: selectedArea,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          items: areas
                              .map(
                                (area) => DropdownMenuItem<String>(
                                  value: area,
                                  child: Text(area),
                                ),
                              )
                              .toList(),
                          onChanged: loading
                              ? null
                              : (value) => setState(() => selectedArea = value!),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _periodSummaryCard(),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: loading ? null : loadFeatures,
                        icon: const Icon(Icons.download_for_offline_rounded),
                        label: const Text('Load Auto Features'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primaryColor.withOpacity(0.55),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (featuresLoaded) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionTitle(
                          Icons.analytics_rounded,
                          'Prediction Features',
                          'Review or modify the automatically loaded feature values.',
                        ),
                        const SizedBox(height: 18),
                        _featureField('Rainfall (mm)', rainfallController, Icons.water_drop_rounded),
                        _featureField('Humidity (%)', humidityController, Icons.water_rounded),
                        _featureField('Temperature (°C)', temperatureController, Icons.thermostat_rounded),
                        _featureField('Dengue Lag 1', lag1Controller, Icons.looks_one_rounded),
                        _featureField('Dengue Lag 2', lag2Controller, Icons.looks_two_rounded),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: loading ? null : predict,
                icon: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.health_and_safety_rounded),
                label: Text(loading ? 'Processing...' : 'Predict Risk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryColor.withOpacity(0.55),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: _primaryColor)),
              ],
              if (riskLevel.isNotEmpty && !_hasPrediction) ...[
                const SizedBox(height: 16),
                _errorCard(),
              ],
              if (_hasPrediction) ...[
                const SizedBox(height: 16),
                resultCard(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
