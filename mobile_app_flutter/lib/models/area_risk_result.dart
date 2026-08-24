class AreaRiskResult {
  final int year;
  final int week;
  final String area;
  final String predictedAreaRiskLevel;

  final double highProbability;
  final double mediumProbability;
  final double lowProbability;

  final String modelUsed;
  final String validation;
  final double? modelAccuracy;
  final double? weightedF1;
  final double? futureProxyCheckAccuracy;
  final double? futureProxyCheckWeightedF1;

  final String inputType;
  final String importantNote;
  final String methodologyNote;
  final Map<String, dynamic> dataContext;

  const AreaRiskResult({
    required this.year,
    required this.week,
    required this.area,
    required this.predictedAreaRiskLevel,
    required this.highProbability,
    required this.mediumProbability,
    required this.lowProbability,
    required this.modelUsed,
    required this.validation,
    required this.modelAccuracy,
    required this.weightedF1,
    required this.futureProxyCheckAccuracy,
    required this.futureProxyCheckWeightedF1,
    required this.inputType,
    required this.importantNote,
    required this.methodologyNote,
    required this.dataContext,
  });

  factory AreaRiskResult.fromJson(Map<String, dynamic> json) {
    final probabilities = _toMap(json['probabilities']);

    return AreaRiskResult(
      year: _toInt(json['year']),
      week: _toInt(json['week']),
      area: _toStringValue(json['area']) ?? 'Unknown',
      predictedAreaRiskLevel:
          _toStringValue(json['predicted_area_risk_level']) ??
          _toStringValue(json['area_risk_level']) ??
          _toStringValue(json['risk_level']) ??
          'Unknown',
      highProbability: _toDouble(
        probabilities['High'] ?? probabilities['high'],
      ),
      mediumProbability: _toDouble(
        probabilities['Medium'] ?? probabilities['medium'],
      ),
      lowProbability: _toDouble(
        probabilities['Low'] ?? probabilities['low'],
      ),
      modelUsed: _toStringValue(json['model_used']) ??
          'Random Forest Area Proxy Risk Model',
      validation: _toStringValue(json['validation']) ??
          'Future-Year Validation',
      modelAccuracy: _toNullableDouble(json['model_accuracy']),
      weightedF1: _toNullableDouble(json['weighted_f1']),
      futureProxyCheckAccuracy:
          _toNullableDouble(json['future_proxy_check_accuracy']),
      futureProxyCheckWeightedF1:
          _toNullableDouble(json['future_proxy_check_weighted_f1']),
      inputType: _toStringValue(json['input_type']) ??
          'area_proxy_prediction',
      importantNote: _toStringValue(json['important_note']) ??
          'This is an MOH-area proxy risk prediction, not a complete official MOH-area surveillance prediction.',
      methodologyNote: _toStringValue(json['methodology_note']) ??
          'The selected area prediction is based on a proxy/context model and is used for area-risk context in the mobile app.',
      dataContext: _toMap(json['data_context']),
    );
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _toStringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }
}