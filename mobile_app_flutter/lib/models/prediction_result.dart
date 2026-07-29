class PredictionResult {
  final int year;
  final int week;
  final int calculatedMonth;
  final String predictedOutbreakLevel;
  final double highProbability;
  final double mediumProbability;
  final double lowProbability;
  final String modelUsed;
  final String validation;
  final String inputType;

  const PredictionResult({
    required this.year,
    required this.week,
    required this.calculatedMonth,
    required this.predictedOutbreakLevel,
    required this.highProbability,
    required this.mediumProbability,
    required this.lowProbability,
    required this.modelUsed,
    required this.validation,
    required this.inputType,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final probabilities =
        Map<String, dynamic>.from(json['probabilities'] as Map);

    return PredictionResult(
      year: (json['year'] as num).toInt(),
      week: (json['week'] as num).toInt(),
      calculatedMonth: (json['calculated_month'] as num).toInt(),
      predictedOutbreakLevel:
          json['predicted_outbreak_level']?.toString() ?? 'Unknown',
      highProbability:
          (probabilities['High'] as num?)?.toDouble() ?? 0.0,
      mediumProbability:
          (probabilities['Medium'] as num?)?.toDouble() ?? 0.0,
      lowProbability:
          (probabilities['Low'] as num?)?.toDouble() ?? 0.0,
      modelUsed: json['model_used']?.toString() ?? '',
      validation: json['validation']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? '',
    );
  }
}