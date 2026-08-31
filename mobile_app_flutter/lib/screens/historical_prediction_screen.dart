import 'package:flutter/material.dart';

import '../services/prediction_api_service.dart';

class HistoricalPredictionScreen extends StatefulWidget {
  const HistoricalPredictionScreen({super.key});

  @override
  State<HistoricalPredictionScreen> createState() =>
      _HistoricalPredictionScreenState();
}

class _HistoricalPredictionScreenState
    extends State<HistoricalPredictionScreen> {
  static const _primaryColor = Color(0xFF00796B);

  late PredictionApiService _api;

  int selectedYear = 2025;
  int selectedWeek = 1;

  final List<int> years = [2025, 2024, 2023, 2022, 2021, 2020];
  final List<int> weeks = List<int>.generate(52, (index) => index + 1);

  bool loading = false;
  String? error;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    _api = PredictionApiService();
  }

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

  Future<void> predictHistorical() async {
    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    try {
      final response = await _api.predictHistorical(
        year: selectedYear,
        week: selectedWeek,
      );

      if (!mounted) return;
      setState(() => result = response);
    } catch (exception) {
      if (!mounted) return;
      setState(() => error = exception.toString());
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

  Widget probabilityBar(String title, dynamic rawValue, Color color) {
    final value = rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue?.toString() ?? '') ?? 0;
    final progressValue = (value / 100).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 10,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 54,
            child: Text(
              rawValue?.toString() ?? '0',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget resultCard() {
    final prediction = result!;
    final risk = (prediction['predicted_outbreak_level'] ??
            prediction['risk_level'] ??
            'Unknown')
        .toString();
    final color = getRiskColor(risk);
    final rawProbabilities = prediction['probabilities'];
    final probabilities = rawProbabilities is Map
        ? Map<String, dynamic>.from(rawProbabilities)
        : <String, dynamic>{};

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
            const SizedBox(height: 6),
            Text(
              getWeekDateRange(selectedYear, selectedWeek),
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
                    risk.toLowerCase() == 'high'
                        ? Icons.warning_rounded
                        : Icons.health_and_safety_rounded,
                    color: color,
                    size: 50,
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Dengue Outbreak Risk',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      '${risk.toUpperCase()} RISK',
                      style: TextStyle(
                        color: color,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (probabilities.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Risk Probabilities',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ...probabilities.entries.map(
                (entry) => probabilityBar(
                  entry.key,
                  entry.value,
                  getRiskColor(entry.key),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, String subtitle) {
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
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundedDropdown({
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
                    label,
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
          const Icon(Icons.event_available_rounded, color: _primaryColor, size: 28),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF6FAFA),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD5E7E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: _primaryColor, size: 25),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to predict',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose a historical year and week, then tap Predict Risk to view the dengue outbreak risk result.',
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
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
              child: Text(error!, style: TextStyle(color: Colors.red.shade900)),
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
        title: const Text('Historical Prediction'),
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
                    Icons.history_rounded,
                    'Historical Dengue Risk',
                    'Explore the predicted outbreak risk for a past week using historical data.',
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
                        Icons.tune_rounded,
                        'Select Prediction Period',
                        'Select the year and epidemiological week to analyse.',
                      ),
                      const SizedBox(height: 18),
                      _roundedDropdown(
                        icon: Icons.calendar_today_rounded,
                        label: 'YEAR',
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
                              : (value) => setState(() => selectedYear = value!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _roundedDropdown(
                        icon: Icons.date_range_rounded,
                        label: 'WEEK',
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
                              : (value) => setState(() => selectedWeek = value!),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _periodSummaryCard(),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: loading ? null : predictHistorical,
                        icon: loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.analytics_rounded),
                        label: Text(loading ? 'Predicting...' : 'Predict Risk'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primaryColor.withOpacity(0.55),
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: _primaryColor)),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                _errorCard(),
              ],
              if (result != null) ...[
                const SizedBox(height: 16),
                resultCard(),
              ] else if (!loading && error == null) ...[
                const SizedBox(height: 16),
                _informationCard(),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}