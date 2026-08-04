import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../services/prediction_api_service.dart';

class DenguePredictionScreen extends StatefulWidget {
  const DenguePredictionScreen({super.key});

  @override
  State<DenguePredictionScreen> createState() => _DenguePredictionScreenState();
}

class _DenguePredictionScreenState extends State<DenguePredictionScreen> {
  final PredictionApiService _apiService = PredictionApiService();

  final List<String> _areas = const [
    'Colombo',
    'Dehiwala',
    'Homagama',
    'Kaduwela',
    'Kesbewa',
    'Kolonnawa',
    'Kotte',
    'Maharagama',
    'Moratuwa',
    'Padukka',
    'Ratmalana',
    'Seethawaka',
    'Thimbirigasyaya',
  ];

  final List<int> _years = const [2026, 2027, 2028, 2029, 2030];

  final List<int> _weeks = List.generate(52, (index) => index + 1);

  String? _selectedArea;
  int _selectedYear = 2026;
  int _selectedWeek = 1;

  bool _isLoading = false;
  PredictionResult? _result;
  String? _errorMessage;

  Future<void> _predictRisk() async {
    if (_isLoading) {
      return;
    }

    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an area before predicting.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.predictFuture(
        year: _selectedYear,
        week: _selectedWeek,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } on PredictionApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to generate the prediction. Please check your '
            'internet connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _riskColor(String risk) {
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

  IconData _riskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.info_rounded;
      case 'low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _monthName(int month) {
    const months = [
      'Unknown',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return 'Unknown';
    }

    return months[month];
  }

  String _formatFeatureName(String key) {
    const customNames = {
      'rainfall_mm': 'Rainfall (mm)',
      'humidity_pct': 'Humidity (%)',
      'temp_max_c': 'Maximum Temperature (°C)',
      'temp_min_c': 'Minimum Temperature (°C)',
      'temp_mean_c': 'Mean Temperature (°C)',
      'dengue_lag_1': 'Dengue Cases - Previous Week',
      'dengue_lag_2': 'Dengue Cases - Two Weeks Ago',
      'rainfall_lag_1': 'Rainfall - Previous Week',
      'humidity_lag_1': 'Humidity - Previous Week',
    };

    if (customNames.containsKey(key)) {
      return customNames[key]!;
    }

    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) {
            return word;
          }

          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String _formatFeatureValue(String key, dynamic value) {
    if (value == null) {
      return 'N/A';
    }

    if (value is num) {
      if (key == 'dengue_lag_1' || key == 'dengue_lag_2') {
        return value.toStringAsFixed(0);
      }

      return value.toStringAsFixed(2);
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      appBar: AppBar(
        title: const Text('Dengue Risk Prediction'),
        centerTitle: true,
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildInputCard(),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                _buildLoadingCard(),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _buildErrorCard(),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildResultCard(_result!),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFE0F2F1),
              child: Icon(
                Icons.health_and_safety,
                color: Color(0xFF00796B),
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colombo District',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select an area and future week to predict dengue risk.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedArea,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Area',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              items: _areas.map((area) {
                return DropdownMenuItem<String>(
                  value: area,
                  child: Text(area, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedArea = value;
                        _result = null;
                        _errorMessage = null;
                      });
                    },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final useVerticalLayout = constraints.maxWidth < 430;

                final yearDropdown = _buildYearDropdown();
                final weekDropdown = _buildWeekDropdown();

                if (useVerticalLayout) {
                  return Column(
                    children: [
                      yearDropdown,
                      const SizedBox(height: 16),
                      weekDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: yearDropdown),
                    const SizedBox(width: 12),
                    Expanded(child: weekDropdown),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _predictRisk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF00796B,
                  ).withValues(alpha: 0.55),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Predicting...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Predict Dengue Risk',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The selected area is used as prediction context. '
              'The current ML model uses Colombo District-level data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Year',
        prefixIcon: Icon(Icons.calendar_today_outlined),
        border: OutlineInputBorder(),
      ),
      items: _years.map((year) {
        return DropdownMenuItem<int>(value: year, child: Text(year.toString()));
      }).toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedYear = value;
                _result = null;
                _errorMessage = null;
              });
            },
    );
  }

  Widget _buildWeekDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedWeek,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Week',
        prefixIcon: Icon(Icons.date_range_outlined),
        border: OutlineInputBorder(),
      ),
      items: _weeks.map((week) {
        return DropdownMenuItem<int>(value: week, child: Text('Week $week'));
      }).toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedWeek = value;
                _result = null;
                _errorMessage = null;
              });
            },
    );
  }

  Widget _buildLoadingCard() {
    return const Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF00796B)),
            SizedBox(height: 14),
            Text(
              'Generating dengue risk prediction...',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'The hosted API may take a few moments to respond.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Prediction Failed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Unable to generate the prediction. '
                      'Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _predictRisk,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(PredictionResult result) {
    final riskColor = _riskColor(result.predictedOutbreakLevel);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prediction for '
              '${_selectedArea ?? 'Selected Area'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              '${result.year} • Week ${result.week} • '
              '${_monthName(result.calculatedMonth)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: riskColor, width: 1.2),
              ),
              child: Column(
                children: [
                  Icon(
                    _riskIcon(result.predictedOutbreakLevel),
                    color: riskColor,
                    size: 52,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${result.predictedOutbreakLevel.toUpperCase()} '
                      'RISK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Prediction Probabilities',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 14),
            _buildProbabilityRow(
              label: 'High',
              probability: result.highProbability,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            _buildProbabilityRow(
              label: 'Medium',
              probability: result.mediumProbability,
              color: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildProbabilityRow(
              label: 'Low',
              probability: result.lowProbability,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            _buildHistoricalAverageNote(),
            const Divider(height: 34),
            const Text(
              'Model Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Model', result.modelUsed),
            _buildInfoRow('Validation', result.validation),
            _buildInfoRow('Accuracy', '84.31%'),
            _buildInfoRow('Weighted F1', '82.11%'),
            const Divider(height: 34),
            _buildAdvancedDetailsSection(result),
            const SizedBox(height: 16),
            _buildDataSourcesSection(result),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Area clarification: The selected area is currently '
                'used as interface context. The prediction itself is '
                'generated using Colombo District-level '
                'machine-learning data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalAverageNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.amber.shade900,
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Important: This prediction is based on historical '
              'seasonal average values, not real-time weather '
              'forecast data.',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbabilityRow({
    required String label,
    required double probability,
    required Color color,
  }) {
    final progress = (probability / 100).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text(
            '${probability.toStringAsFixed(2)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: const TextStyle(color: Colors.black54, height: 1.35),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedDetailsSection(PredictionResult result) {
    if (result.autoGeneratedFeatures.isEmpty) {
      return const SizedBox.shrink();
    }

    const fieldsToShow = [
      'rainfall_mm',
      'humidity_pct',
      'temp_max_c',
      'temp_min_c',
      'temp_mean_c',
      'dengue_lag_1',
      'dengue_lag_2',
      'rainfall_lag_1',
      'humidity_lag_1',
    ];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text(
        'Advanced Details',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      subtitle: const Text(
        'Automatically generated model input values',
        style: TextStyle(fontSize: 12),
      ),
      children: fieldsToShow.map((key) {
        final value = result.autoGeneratedFeatures[key];

        return _buildInfoRow(
          _formatFeatureName(key),
          _formatFeatureValue(key, value),
        );
      }).toList(),
    );
  }

  Widget _buildDataSourcesSection(PredictionResult result) {
    if (result.dataSourcesUsed.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text(
        'Data Sources Used',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      subtitle: const Text(
        'Data information returned by the API',
        style: TextStyle(fontSize: 12),
      ),
      children: result.dataSourcesUsed.entries.map((entry) {
        return _buildInfoRow(
          _formatFeatureName(entry.key),
          entry.value.toString(),
        );
      }).toList(),
    );
  }
}
