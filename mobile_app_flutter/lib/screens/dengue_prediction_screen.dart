import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../models/area_risk_result.dart';
import '../services/prediction_api_service.dart';

enum PredictionInputMode {
  week,
  date,
}

class _PredictionHistoryItem {
  final String area;
  final int year;
  final int week;
  final String weekDateRange;
  final String riskLevel;
  final double highProbability;
  final double mediumProbability;
  final double lowProbability;
  final DateTime? selectedDate;

  const _PredictionHistoryItem({
    required this.area,
    required this.year,
    required this.week,
    required this.weekDateRange,
    required this.riskLevel,
    required this.highProbability,
    required this.mediumProbability,
    required this.lowProbability,
    this.selectedDate,
  });
}

class DenguePredictionScreen extends StatefulWidget {
  const DenguePredictionScreen({super.key});

  @override
  State<DenguePredictionScreen> createState() =>
      _DenguePredictionScreenState();
}

class _DenguePredictionScreenState
    extends State<DenguePredictionScreen> {
  final PredictionApiService _apiService =
      PredictionApiService();

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

  final List<int> _years = const [
    2026,
    2027,
    2028,
    2029,
    2030,
  ];

  // Keeps the last 3 predictions while the app process/session is active.
  static final List<_PredictionHistoryItem>
      _sessionPredictionHistory = [];

  PredictionInputMode _predictionInputMode =
      PredictionInputMode.week;

  String? _selectedArea;

  int _selectedYear = 2026;
  int _selectedWeek = 1;

  DateTime? _selectedPredictionDate;

  bool _isLoading = false;

  PredictionResult? _result;
  AreaRiskResult? _areaRiskResult;

  String? _errorMessage;
  String? _areaRiskErrorMessage;

  PredictionInputMode? _lastPredictionMode;
  String? _lastPredictionArea;
  DateTime? _lastPredictionDate;
  int? _lastPredictionYear;
  int? _lastPredictionWeek;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    if (_years.contains(now.year)) {
      _selectedYear = now.year;
      _selectedWeek = _calculateWeekNumber(now);
    } else if (now.year < _years.first) {
      _selectedYear = _years.first;
      _selectedWeek = 1;
    } else {
      _selectedYear = _years.last;
      _selectedWeek = _weekCountForYear(
        _years.last,
      );
    }
  }

  // ------------------------------------------------------------
  // DATE / WEEK CALCULATIONS
  // ------------------------------------------------------------

  int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(
      date.year,
      1,
      1,
    );

    return date
            .difference(startOfYear)
            .inDays +
        1;
  }

  int _calculateWeekNumber(DateTime date) {
    final dayOfYear = _dayOfYear(date);

    return ((dayOfYear - 1) ~/ 7) + 1;
  }

  int _weekCountForYear(int year) {
    final daysInYear = DateTime(
      year + 1,
      1,
      1,
    ).difference(
      DateTime(year, 1, 1),
    ).inDays;

    return ((daysInYear - 1) ~/ 7) + 1;
  }

  DateTime _weekStartDate(
    int year,
    int week,
  ) {
    return DateTime(
      year,
      1,
      1,
    ).add(
      Duration(
        days: (week - 1) * 7,
      ),
    );
  }

  DateTime _weekEndDate(
    int year,
    int week,
  ) {
    final startDate = _weekStartDate(
      year,
      week,
    );

    final calculatedEnd = startDate.add(
      const Duration(days: 6),
    );

    final lastDayOfYear = DateTime(
      year,
      12,
      31,
    );

    if (calculatedEnd.isAfter(
      lastDayOfYear,
    )) {
      return lastDayOfYear;
    }

    return calculatedEnd;
  }

  String _shortMonthName(int month) {
    const months = [
      'Unknown',
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

    if (month < 1 || month > 12) {
      return 'Unknown';
    }

    return months[month];
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

  String _formatDate(DateTime date) {
    return '${_shortMonthName(date.month)} '
        '${date.day}, ${date.year}';
  }

  String _formatWeekDateRange(
    int year,
    int week,
  ) {
    final startDate = _weekStartDate(
      year,
      week,
    );

    final endDate = _weekEndDate(
      year,
      week,
    );

    if (startDate.month == endDate.month) {
      return '${_shortMonthName(startDate.month)} '
          '${startDate.day} - ${endDate.day}';
    }

    return '${_shortMonthName(startDate.month)} '
        '${startDate.day} - '
        '${_shortMonthName(endDate.month)} '
        '${endDate.day}';
  }

  String _predictionPeriodLabel(
    int year,
    int week,
  ) {
    return 'Week $week · '
        '${_formatWeekDateRange(year, week)}';
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  DateTime _initialDateForPicker() {
    final firstDate = DateTime(
      _years.first,
      1,
      1,
    );

    final lastDate = DateTime(
      _years.last,
      12,
      31,
    );

    final now = DateTime.now();

    if (_selectedPredictionDate != null) {
      return _selectedPredictionDate!;
    }

    if (now.isBefore(firstDate)) {
      return firstDate;
    }

    if (now.isAfter(lastDate)) {
      return lastDate;
    }

    return now;
  }

  Future<void> _selectPredictionDate() async {
    if (_isLoading) {
      return;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _initialDateForPicker(),
      firstDate: DateTime(
        _years.first,
        1,
        1,
      ),
      lastDate: DateTime(
        _years.last,
        12,
        31,
      ),
      helpText: 'Select Prediction Date',
      confirmText: 'SELECT',
      cancelText: 'CANCEL',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedPredictionDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      _result = null;
      _areaRiskResult = null;
      _errorMessage = null;
      _areaRiskErrorMessage = null;
    });
  }

  // ------------------------------------------------------------
  // PREDICTION
  // ------------------------------------------------------------

  Future<void> _predictRisk() async {
    if (_isLoading) {
      return;
    }

    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an area before predicting.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    late final int requestYear;
    late final int requestWeek;

    DateTime? requestDate;

    if (_predictionInputMode ==
        PredictionInputMode.date) {
      if (_selectedPredictionDate == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Please select a prediction date.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );

        return;
      }

      final selectedDate =
          _selectedPredictionDate!;

      requestDate = selectedDate;
      requestYear = selectedDate.year;

      // Frontend converts calendar date to week.
      requestWeek = _calculateWeekNumber(
        selectedDate,
      );
    } else {
      requestYear = _selectedYear;
      requestWeek = _selectedWeek;
    }

    final requestArea = _selectedArea!;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;

      _lastPredictionMode =
          _predictionInputMode;

      _lastPredictionArea =
          requestArea;

      _lastPredictionDate =
          requestDate;

      _lastPredictionYear =
          requestYear;

      _lastPredictionWeek =
          requestWeek;
    });

    try {
      // Backend receives only year + week.
      final districtResult = await _apiService.predictFuture(
  year: requestYear,
  week: requestWeek,
);

AreaRiskResult? areaResult;
String? areaError;

try {
  areaResult = await _apiService.predictAreaRisk(
    year: requestYear,
    week: requestWeek,
    area: requestArea,
  );
} on PredictionApiException catch (error) {
  areaError = error.message;
} catch (_) {
  areaError =
      'Unable to generate the selected area proxy risk prediction.';
}

if (!mounted) {
  return;
}

setState(() {
  _result = districtResult;
  _areaRiskResult = areaResult;
  _areaRiskErrorMessage = areaError;

  _addPredictionToHistory(
    area: requestArea,
    year: requestYear,
    week: requestWeek,
    selectedDate: requestDate,
    result: districtResult,
  );
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
            'Unable to generate the prediction. '
            'Please check your internet connection '
            'and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // PREDICTION HISTORY
  // ------------------------------------------------------------

  void _addPredictionToHistory({
    required String area,
    required int year,
    required int week,
    required DateTime? selectedDate,
    required PredictionResult result,
  }) {
    final item = _PredictionHistoryItem(
      area: area,
      year: year,
      week: week,
      weekDateRange:
          _formatWeekDateRange(
        year,
        week,
      ),
      riskLevel:
          result.predictedOutbreakLevel,
      highProbability:
          result.highProbability,
      mediumProbability:
          result.mediumProbability,
      lowProbability:
          result.lowProbability,
      selectedDate: selectedDate,
    );

    _sessionPredictionHistory.insert(
      0,
      item,
    );

    if (_sessionPredictionHistory.length >
        3) {
      _sessionPredictionHistory.removeLast();
    }
  }

  // ------------------------------------------------------------
  // RISK UI HELPERS
  // ------------------------------------------------------------

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

  String _riskAwarenessMessage(
    String risk,
  ) {
    switch (risk.toLowerCase()) {
      case 'low':
        return 'Routine dengue prevention awareness '
            'is recommended.';

      case 'medium':
        return 'Maintain mosquito breeding site '
            'inspections and increase public awareness.';

      case 'high':
        return 'High dengue risk detected. '
            'Public health attention and preventive '
            'awareness should be prioritized.';

      default:
        return 'Continue dengue prevention awareness '
            'and monitor public health information.';
    }
  }

  // ------------------------------------------------------------
  // FEATURE FORMATTING
  // ------------------------------------------------------------

  String _formatFeatureName(String key) {
    const customNames = {
      'rainfall_mm': 'Rainfall (mm)',
      'humidity_pct': 'Humidity (%)',
      'temp_max_c':
          'Maximum Temperature (°C)',
      'temp_min_c':
          'Minimum Temperature (°C)',
      'temp_mean_c':
          'Mean Temperature (°C)',
      'dengue_lag_1':
          'Dengue Cases - Previous Week',
      'dengue_lag_2':
          'Dengue Cases - Two Weeks Ago',
      'rainfall_lag_1':
          'Rainfall - Previous Week',
      'humidity_lag_1':
          'Humidity - Previous Week',
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

          return word[0].toUpperCase() +
              word.substring(1);
        })
        .join(' ');
  }

  String _formatFeatureValue(
    String key,
    dynamic value,
  ) {
    if (value == null) {
      return 'N/A';
    }

    if (value is num) {
      if (key == 'dengue_lag_1' ||
          key == 'dengue_lag_2') {
        return value.toStringAsFixed(0);
      }

      return value.toStringAsFixed(2);
    }

    return value.toString();
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7F8),
      appBar: AppBar(
        title:
            const Text(
          'Dengue Risk Prediction',
        ),
        centerTitle: true,
        backgroundColor:
            const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(16),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                if (_areaRiskResult != null)
                  _buildAreaRiskCard(_areaRiskResult!)
                else if (_areaRiskErrorMessage != null)
                  _buildAreaRiskUnavailableCard(_areaRiskErrorMessage!),
              ],

              if (_sessionPredictionHistory
                  .isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPredictionHistorySection(),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor:
                  Color(0xFFE0F2F1),
              child: Icon(
                Icons.health_and_safety,
                color: Color(0xFF00796B),
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colombo District',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Select an area and predict dengue '
                    'risk by week or by calendar date.',
                    style:
                        TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // INPUT CARD
  // ------------------------------------------------------------

  Widget _buildInputCard() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Prediction Method',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            _buildPredictionModeSelector(),

            const SizedBox(height: 18),

            DropdownButtonFormField<String>(
              initialValue:
                  _selectedArea,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                labelText: 'Select Area',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              items:
                  _areas.map((area) {
                return DropdownMenuItem<
                    String>(
                  value: area,
                  child: Text(
                    area,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedArea =
                            value;

                        _result = null;
                        _errorMessage =
                            null;
                      });
                    },
            ),

            const SizedBox(height: 16),

            AnimatedSwitcher(
              duration:
                  const Duration(
                milliseconds: 220,
              ),
              child:
                  _predictionInputMode ==
                          PredictionInputMode
                              .week
                      ? _buildWeekModeInputs()
                      : _buildDateModeInputs(),
            ),

            const SizedBox(height: 16),

            _buildPredictionPeriodPreview(),

            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _predictRisk,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF00796B,
                  ),
                  foregroundColor:
                      Colors.white,
                  disabledBackgroundColor:
                      const Color(
                    0xFF00796B,
                  ).withValues(
                    alpha: 0.55,
                  ),
                  disabledForegroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          SizedBox(
                            width: 21,
                            height: 21,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  Colors.white,
                            ),
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Text(
                            'Predicting...',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons
                                .analytics_outlined,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                            'Predict Dengue Risk',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'The selected area is used as prediction '
              'context. The current ML model uses '
              'Colombo District-level data.',
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

  // ------------------------------------------------------------
  // WEEK / DATE MODE SELECTOR
  // ------------------------------------------------------------

  Widget _buildPredictionModeSelector() {
    return SegmentedButton<
        PredictionInputMode>(
      segments: const [
        ButtonSegment<
            PredictionInputMode>(
          value:
              PredictionInputMode.week,
          icon: Icon(
            Icons.date_range_outlined,
          ),
          label: Text('By Week'),
        ),
        ButtonSegment<
            PredictionInputMode>(
          value:
              PredictionInputMode.date,
          icon: Icon(
            Icons.calendar_month_outlined,
          ),
          label: Text('By Date'),
        ),
      ],
      selected: {
        _predictionInputMode,
      },
      showSelectedIcon: false,
      onSelectionChanged:
          _isLoading
              ? null
              : (selection) {
                  setState(() {
                    _predictionInputMode =
                        selection.first;

                    _result = null;
                    _errorMessage = null;
                  });
                },
    );
  }

  // ------------------------------------------------------------
  // WEEK MODE
  // ------------------------------------------------------------

  Widget _buildWeekModeInputs() {
    return LayoutBuilder(
      key:
          const ValueKey('week-mode'),
      builder:
          (context, constraints) {
        final useVerticalLayout =
            constraints.maxWidth < 430;

        final yearDropdown =
            _buildYearDropdown();

        final weekDropdown =
            _buildWeekDropdown();

        if (useVerticalLayout) {
          return Column(
            children: [
              yearDropdown,
              const SizedBox(
                height: 16,
              ),
              weekDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: yearDropdown,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: weekDropdown,
            ),
          ],
        );
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      isExpanded: true,
      decoration:
          const InputDecoration(
        labelText: 'Year',
        prefixIcon: Icon(
          Icons.calendar_today_outlined,
        ),
        border: OutlineInputBorder(),
      ),
      items:
          _years.map((year) {
        return DropdownMenuItem<int>(
          value: year,
          child: Text(
            year.toString(),
          ),
        );
      }).toList(),
      onChanged: _isLoading
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedYear = value;

                final maxWeek =
                    _weekCountForYear(
                  _selectedYear,
                );

                if (_selectedWeek >
                    maxWeek) {
                  _selectedWeek =
                      maxWeek;
                }

                _result = null;
                _errorMessage = null;
              });
            },
    );
  }

  Widget _buildWeekDropdown() {
    final weeks =
        List.generate(
      _weekCountForYear(
        _selectedYear,
      ),
      (index) => index + 1,
    );

    return DropdownButtonFormField<int>(
      initialValue: _selectedWeek,
      isExpanded: true,
      decoration:
          const InputDecoration(
        labelText: 'Week',
        prefixIcon: Icon(
          Icons.date_range_outlined,
        ),
        border: OutlineInputBorder(),
      ),
      items:
          weeks.map((week) {
        return DropdownMenuItem<int>(
          value: week,
          child: Text(
            _predictionPeriodLabel(
              _selectedYear,
              week,
            ),
            overflow:
                TextOverflow.ellipsis,
          ),
        );
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

  // ------------------------------------------------------------
  // DATE MODE
  // ------------------------------------------------------------

  Widget _buildDateModeInputs() {
    return Column(
      key:
          const ValueKey('date-mode'),
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _isLoading
              ? null
              : _selectPredictionDate,
          borderRadius:
              BorderRadius.circular(4),
          child: InputDecorator(
            decoration:
                InputDecoration(
              labelText:
                  'Prediction Date',
              prefixIcon:
                  const Icon(
                Icons
                    .calendar_today_outlined,
              ),
              suffixIcon:
                  const Icon(
                Icons.arrow_drop_down,
              ),
              border:
                  const OutlineInputBorder(),
              enabled: !_isLoading,
            ),
            child: Text(
              _selectedPredictionDate ==
                      null
                  ? 'Select a calendar date'
                  : _formatDate(
                      _selectedPredictionDate!,
                    ),
              style: TextStyle(
                color:
                    _selectedPredictionDate ==
                            null
                        ? Colors.black54
                        : Colors.black87,
                fontWeight:
                    _selectedPredictionDate ==
                            null
                        ? FontWeight.normal
                        : FontWeight.w600,
              ),
            ),
          ),
        ),

        if (_selectedPredictionDate !=
            null) ...[
          const SizedBox(height: 12),

          _buildCalculatedDateInfo(
            _selectedPredictionDate!,
          ),
        ],
      ],
    );
  }

  Widget _buildCalculatedDateInfo(
    DateTime date,
  ) {
    final calculatedWeek =
        _calculateWeekNumber(date);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            const Color(0xFFE0F2F1),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              const Color(0xFF80CBC4),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons
                    .auto_awesome_outlined,
                size: 19,
                color:
                    Color(0xFF00695C),
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Auto-calculated Prediction Week',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(
                      0xFF00695C,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _predictionPeriodLabel(
              date.year,
              calculatedWeek,
            ),
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Year: ${date.year}  •  '
            'Month: ${_monthName(date.month)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PREDICTION PERIOD PREVIEW
  // ------------------------------------------------------------

  Widget _buildPredictionPeriodPreview() {
    if (_predictionInputMode ==
            PredictionInputMode.date &&
        _selectedPredictionDate ==
            null) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              Colors.blueGrey.shade50,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color:
                Colors.blueGrey.shade100,
          ),
        ),
        child: const Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.event_note_outlined,
              color: Colors.blueGrey,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select a calendar date to calculate '
                'the prediction period.',
                style: TextStyle(
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    late final int year;
    late final int week;

    DateTime? selectedDate;

    if (_predictionInputMode ==
        PredictionInputMode.date) {
      selectedDate =
          _selectedPredictionDate!;

      year = selectedDate.year;

      week =
          _calculateWeekNumber(
        selectedDate,
      );
    } else {
      year = _selectedYear;
      week = _selectedWeek;
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(0xFFF1F8E9),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFAED581),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: Color(0xFF558B2F),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediction Period',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.black54,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _predictionPeriodLabel(
                    year,
                    week,
                  ),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                if (selectedDate !=
                    null) ...[
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    'Selected Date: '
                    '${_formatDate(selectedDate)}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LOADING
  // ------------------------------------------------------------

  Widget _buildLoadingCard() {
    return const Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircularProgressIndicator(
              color:
                  Color(0xFF00796B),
            ),

            SizedBox(height: 14),

            Text(
              'Generating dengue risk prediction...',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            SizedBox(height: 6),

            Text(
              'The hosted API may take a few moments '
              'to respond.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ERROR CARD
  // ------------------------------------------------------------

  Widget _buildErrorCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 42,
            ),

            const SizedBox(height: 10),

            const Text(
              'Prediction Failed',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _errorMessage ??
                  'Unable to generate the prediction. '
                      'Please try again.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                height: 1.4,
              ),
            ),

            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : _predictRisk,
              icon:
                  const Icon(
                Icons.refresh,
              ),
              label:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RESULT DETAILS
  // ------------------------------------------------------------

  Widget _buildResultPredictionDetails({
    required String area,
    required int year,
    required int week,
    required int calculatedMonth,
  }) {
    final isDatePrediction =
        _lastPredictionMode ==
                PredictionInputMode.date &&
            _lastPredictionDate != null;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(0xFFE0F2F1),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFF80CBC4),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 20,
                color:
                    Color(0xFF00695C),
              ),
              SizedBox(width: 8),
              Text(
                'Prediction Details',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 15,
                  color:
                      Color(
                    0xFF00695C,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _buildResultDetailRow(
            icon:
                Icons.location_on_outlined,
            label: 'Area Context',
            value: area,
          ),

          const Divider(height: 20),

          _buildResultDetailRow(
            icon:
                Icons.date_range_outlined,
            label: 'Week',
            value: 'Week $week',
          ),

          const Divider(height: 20),

          _buildResultDetailRow(
            icon:
                Icons.event_outlined,
            label: 'Date Range',
            value:
                _formatWeekDateRange(
              year,
              week,
            ),
          ),

          if (isDatePrediction) ...[
            const Divider(
              height: 20,
            ),

            _buildResultDetailRow(
              icon:
                  Icons
                      .calendar_today_outlined,
              label:
                  'Selected Date',
              value:
                  _formatDate(
                _lastPredictionDate!,
              ),
            ),
          ],

          const Divider(height: 20),

          _buildResultDetailRow(
            icon:
                Icons.calendar_month_outlined,
            label: 'Month',
            value:
                _monthName(
              calculatedMonth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color:
              const Color(0xFF00796B),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 92,
          child: Text(
            label,
            style:
                const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // RESULT CARD
  // ------------------------------------------------------------

  Widget _buildResultCard(
    PredictionResult result,
  ) {
    final riskColor = _riskColor(
      result.predictedOutbreakLevel,
    );

    final resultArea =
        _lastPredictionArea ??
            _selectedArea ??
            'Selected Area';

    final resultYear =
        _lastPredictionYear ??
            result.year;

    final resultWeek =
        _lastPredictionWeek ??
            result.week;

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dengue Risk Prediction Result',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 14),

            _buildResultPredictionDetails(
              area: resultArea,
              year: resultYear,
              week: resultWeek,
              calculatedMonth:
                  result.calculatedMonth,
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 22,
              ),
              decoration:
                  BoxDecoration(
                color:
                    riskColor.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color: riskColor,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _riskIcon(
                      result
                          .predictedOutbreakLevel,
                    ),
                    color: riskColor,
                    size: 52,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  FittedBox(
                    fit:
                        BoxFit.scaleDown,
                    child: Text(
                      '${result.predictedOutbreakLevel.toUpperCase()} RISK',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                        fontSize: 26,
                        color:
                            riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Prediction Probabilities',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 17,
              ),
            ),

            const SizedBox(height: 14),

            _buildProbabilityRow(
              label: 'High',
              probability:
                  result.highProbability,
              color: Colors.red,
            ),

            const SizedBox(height: 12),

            _buildProbabilityRow(
              label: 'Medium',
              probability:
                  result.mediumProbability,
              color: Colors.orange,
            ),

            const SizedBox(height: 12),

            _buildProbabilityRow(
              label: 'Low',
              probability:
                  result.lowProbability,
              color: Colors.green,
            ),

            const SizedBox(height: 20),

            _buildRiskAwarenessCard(
              result.predictedOutbreakLevel,
            ),

            const SizedBox(height: 16),

            _buildHistoricalAverageNote(),

            const Divider(height: 34),

            _buildAdvancedDetailsSection(
              result,
            ),

            const SizedBox(height: 16),

            _buildDataSourcesSection(
              result,
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(
                color: Colors
                    .blueGrey.shade50,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: const Text(
                'Area clarification: The selected area '
                'is currently used as interface context. '
                'The prediction itself is generated using '
                'Colombo District-level machine-learning data.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // RISK AWARENESS
  // ------------------------------------------------------------

  Widget _buildRiskAwarenessCard(
    String risk,
  ) {
    final riskColor =
        _riskColor(risk);

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            riskColor.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              riskColor.withValues(
            alpha: 0.6,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .campaign_outlined,
            color: riskColor,
            size: 24,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Awareness',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        riskColor,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  _riskAwarenessMessage(
                    risk,
                  ),
                  style:
                      const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // IMPORTANT NOTE
  // ------------------------------------------------------------

  Widget _buildHistoricalAverageNote() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            Colors.amber.shade50,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              Colors.amber.shade700,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color:
                Colors.amber.shade900,
            size: 23,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Important: This prediction is based on '
              'historical seasonal average values, not '
              'real-time weather forecast data.',
              style:
                  TextStyle(
                color:
                    Colors.amber.shade900,
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PROBABILITY ROW
  // ------------------------------------------------------------

  Widget _buildProbabilityRow({
    required String label,
    required double probability,
    required Color color,
  }) {
    final progress =
        (probability / 100)
            .clamp(
          0.0,
          1.0,
        );

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Expanded(
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: color,
              backgroundColor:
                  color.withValues(
                alpha: 0.15,
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        SizedBox(
          width: 62,
          child: Text(
            '${probability.toStringAsFixed(2)}%',
            textAlign:
                TextAlign.right,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // MODEL INFO ROW
  // ------------------------------------------------------------

  Widget _buildInfoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style:
                  const TextStyle(
                color:
                    Colors.black54,
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ADVANCED DETAILS
  // ------------------------------------------------------------

  Widget _buildAdvancedDetailsSection(
    PredictionResult result,
  ) {
    if (result
        .autoGeneratedFeatures
        .isEmpty) {
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
      childrenPadding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      title:
          const Text(
        'Advanced Details',
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
          fontSize: 17,
        ),
      ),
      subtitle:
          const Text(
        'Automatically generated model input values',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
      children:
          fieldsToShow.map((key) {
        final value =
            result.autoGeneratedFeatures[
                key];

        return _buildInfoRow(
          _formatFeatureName(key),
          _formatFeatureValue(
            key,
            value,
          ),
        );
      }).toList(),
    );
  }

  // ------------------------------------------------------------
  // DATA SOURCES
  // ------------------------------------------------------------

  Widget _buildDataSourcesSection(
    PredictionResult result,
  ) {
    if (result
        .dataSourcesUsed
        .isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      title:
          const Text(
        'Data Sources Used',
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
          fontSize: 17,
        ),
      ),
      subtitle:
          const Text(
        'Data information returned by the API',
        style: TextStyle(
          fontSize: 12,
        ),
      ),
      children: result
          .dataSourcesUsed.entries
          .map(
        (entry) {
          return _buildInfoRow(
            _formatFeatureName(
              entry.key,
            ),
            entry.value.toString(),
          );
        },
      ).toList(),
    );
  }

  // ------------------------------------------------------------
  // PREDICTION HISTORY
  // ------------------------------------------------------------

  Widget _buildPredictionHistorySection() {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color:
                      Color(
                    0xFF00796B,
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Prediction History',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            const Text(
              'Last 3 predictions from this app session',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 14),

            ...List.generate(
              _sessionPredictionHistory
                  .length,
              (index) {
                final item =
                    _sessionPredictionHistory[
                        index];

                return Padding(
                  padding:
                      EdgeInsets.only(
                    bottom: index ==
                            _sessionPredictionHistory
                                    .length -
                                1
                        ? 0
                        : 12,
                  ),
                  child:
                      _buildHistoryItem(
                    item,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    _PredictionHistoryItem item,
  ) {
    final riskColor =
        _riskColor(
      item.riskLevel,
    );

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            riskColor.withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              riskColor.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.area} · ${item.year} Week ${item.week}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      riskColor.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  '${item.riskLevel} Risk',
                  style:
                      TextStyle(
                    color:
                        riskColor,
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            item.weekDateRange,
            style:
                const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),

          if (item.selectedDate !=
              null) ...[
            const SizedBox(height: 3),
            Text(
              'Selected Date: '
              '${_formatDate(item.selectedDate!)}',
              style:
                  const TextStyle(
                color:
                    Colors.black54,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 9),

          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              Text(
                'High '
                '${item.highProbability.toStringAsFixed(1)}%',
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Colors.red,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              Text(
                'Medium '
                '${item.mediumProbability.toStringAsFixed(1)}%',
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Colors.orange,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              Text(
                'Low '
                '${item.lowProbability.toStringAsFixed(1)}%',
                style:
                    const TextStyle(
                  fontSize: 11,
                  color:
                      Colors.green,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAreaRiskCard(AreaRiskResult result) {
    final riskColor = _riskColor(result.predictedAreaRiskLevel);

    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selected Area Risk Context',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'MOH-area proxy risk prediction',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 22,
              ),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: riskColor,
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _riskIcon(result.predictedAreaRiskLevel),
                    color: riskColor,
                    size: 52,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.area,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${result.predictedAreaRiskLevel.toUpperCase()} AREA RISK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Area Risk Probabilities',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
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
            const SizedBox(height: 18),
            _buildAreaModelInfoSection(result),
            const SizedBox(height: 16),
            _buildAreaMethodologyNote(result),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaRiskUnavailableCard(String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.orange,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Area risk context unavailable: $message',
                style: const TextStyle(
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaModelInfoSection(AreaRiskResult result) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text(
        'Area Model Information',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      subtitle: const Text(
        'Proxy area-risk model details',
        style: TextStyle(fontSize: 12),
      ),
      children: [
        _buildInfoRow('Model Used', result.modelUsed),
        _buildInfoRow('Validation', result.validation),
        if (result.modelAccuracy != null)
          _buildInfoRow(
            'Model Accuracy',
            '${result.modelAccuracy!.toStringAsFixed(2)}%',
          ),
        if (result.weightedF1 != null)
          _buildInfoRow(
            'Weighted F1',
            '${result.weightedF1!.toStringAsFixed(2)}%',
          ),
        if (result.futureProxyCheckAccuracy != null)
          _buildInfoRow(
            '2026 Proxy Check Accuracy',
            '${result.futureProxyCheckAccuracy!.toStringAsFixed(2)}%',
          ),
        if (result.futureProxyCheckWeightedF1 != null)
          _buildInfoRow(
            '2026 Proxy Check Weighted F1',
            '${result.futureProxyCheckWeightedF1!.toStringAsFixed(2)}%',
          ),
        _buildInfoRow('Input Type', result.inputType),
        ...result.dataContext.entries.map(
          (entry) => _buildInfoRow(
            _formatFeatureName(entry.key),
            entry.value.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaMethodologyNote(AreaRiskResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.deepPurple.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fact_check_outlined,
            color: Colors.deepPurple.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${result.importantNote}\n\n${result.methodologyNote}',
              style: TextStyle(
                color: Colors.deepPurple.shade900,
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
}