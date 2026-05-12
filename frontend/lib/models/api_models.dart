class DashboardData {
  final String riskLevel;
  final double confidence;
  final Map<String, dynamic> current;
  final List<dynamic> topXai;
  DashboardData.fromJson(Map<String, dynamic> j)
      : riskLevel = j['risk_level'] ?? 'Medium',
        confidence = (j['confidence'] ?? 0).toDouble(),
        current = Map<String, dynamic>.from(j['current'] ?? {}),
        topXai = List<dynamic>.from(j['top_xai'] ?? []);
}

class PredictionResult {
  final String riskLevel;
  final double confidence;
  final Map<String, double> probabilities;
  final List<dynamic> xaiLocal;
  final List<dynamic> recommendations;
  final String topReason;
  PredictionResult.fromJson(Map<String, dynamic> j)
      : riskLevel = j['risk_level'] ?? 'Unknown',
        confidence = (j['confidence'] ?? 0).toDouble(),
        probabilities = Map<String, double>.from((j['probabilities'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        xaiLocal = List<dynamic>.from(j['xai_local'] ?? []),
        recommendations = List<dynamic>.from(j['recommendations'] ?? []),
        topReason = j['top_reason'] ?? '';
}

class PredictionInput {
  final Map<String, double> values;
  PredictionInput(this.values);
  Map<String, dynamic> toJson() => values;
  static const features = ['year','week','month','temp_max_c','temp_min_c','temp_mean_c','feelslikemax','feelslikemin','feelslike','dew','humidity_pct','rainfall_mm','precipprob','precipcover','wind_speed_kmh','winddir','sealevelpressure','cloudcover','visibility','solarradiation','solarenergy','uvindex'];
  static Map<String,double> defaults() => {'year':2024,'week':1,'month':1,'temp_max_c':31.8,'temp_min_c':24.4,'temp_mean_c':28.7,'feelslikemax':39.7,'feelslikemin':25.3,'feelslike':32.3,'dew':22.9,'humidity_pct':77.5,'rainfall_mm':69.8,'precipprob':44.6,'precipcover':4.3,'wind_speed_kmh':5.0,'winddir':175.5,'sealevelpressure':1007.9,'cloudcover':50.7,'visibility':3.8,'solarradiation':208.0,'solarenergy':17.9,'uvindex':7.2};
}
