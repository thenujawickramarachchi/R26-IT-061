import React, { useState } from "react";
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

export default function HomeScreen() {
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const API_URL = "http://192.168.1.2:8000/predict";

  const inputData = {
    year: 2026,
    week: 20,
    month: 5,
    temp_max_c: 31.2,
    temp_min_c: 25.4,
    temp_mean_c: 28.3,
    feelslikemax: 36.0,
    feelslikemin: 27.0,
    feelslike: 31.2,
    dew: 24.5,
    humidity_pct: 82.0,
    rainfall_mm: 45.0,
    precipprob: 80.0,
    precipcover: 12.0,
    wind_speed_kmh: 15.3,
    winddir: 210.0,
    sealevelpressure: 1010.0,
    cloudcover: 75.0,
    visibility: 9.5,
    solarradiation: 180.0,
    solarenergy: 15.0,
    uvindex: 6.0,
  };

  const predictOutbreak = async () => {

    try {
      setLoading(true);
      setResult(null);

      const response = await fetch(API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(inputData),
      });

      if (!response.ok) {
        throw new Error("API request failed");
      }

      const data = await response.json();
      setResult(data);
    } catch (error: any) {
  console.log("API Error:", error);
  Alert.alert("API Error", error.message || "Could not connect to prediction API");
} finally {
  setLoading(false);
}
  };

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>Dengue Outbreak Prediction</Text>

        <View style={styles.card}>
          <Text style={styles.subtitle}>Sample Input</Text>
          <Text style={styles.text}>Year: {inputData.year}</Text>
          <Text style={styles.text}>Week: {inputData.week}</Text>
          <Text style={styles.text}>Month: {inputData.month}</Text>
          <Text style={styles.text}>Rainfall: {inputData.rainfall_mm} mm</Text>
          <Text style={styles.text}>Humidity: {inputData.humidity_pct}%</Text>
          <Text style={styles.text}>
            Mean Temperature: {inputData.temp_mean_c}°C
          </Text>
        </View>

        <Pressable
          style={[styles.button, loading && styles.buttonDisabled]}
          onPress={predictOutbreak}
          disabled={loading}
        >
          <Text style={styles.buttonText}>
            {loading ? "Predicting..." : "Predict Outbreak Level"}
          </Text>
        </Pressable>

        {result && (
          <View style={styles.resultCard}>
            <Text style={styles.subtitle}>Prediction Result</Text>

            <Text style={styles.prediction}>
              Predicted Level: {result.predicted_outbreak_level}
            </Text>

            <Text style={styles.text}>Model Used: {result.model_used}</Text>

            <Text style={styles.subtitle}>Probabilities</Text>
            <Text style={styles.text}>
              High: {(result.probabilities.High * 100).toFixed(1)}%
            </Text>
            <Text style={styles.text}>
              Low: {(result.probabilities.Low * 100).toFixed(1)}%
            </Text>
            <Text style={styles.text}>
              Medium: {(result.probabilities.Medium * 100).toFixed(1)}%
            </Text>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#f5f7fb",
  },
  container: {
    paddingTop: 70,
    paddingHorizontal: 20,
    paddingBottom: 120,
  },
  title: {
    fontSize: 26,
    fontWeight: "bold",
    marginBottom: 20,
    color: "#1f2937",
  },
  card: {
    backgroundColor: "#ffffff",
    padding: 20,
    borderRadius: 16,
    marginBottom: 24,
  },
  resultCard: {
    backgroundColor: "#ffffff",
    padding: 20,
    borderRadius: 16,
    marginTop: 24,
  },
  subtitle: {
    fontSize: 20,
    fontWeight: "bold",
    marginBottom: 12,
    color: "#111827",
  },
  text: {
    fontSize: 16,
    marginBottom: 4,
    color: "#111827",
  },
  button: {
    backgroundColor: "#2d9bf0",
    paddingVertical: 16,
    borderRadius: 8,
    alignItems: "center",
  },
  buttonDisabled: {
    opacity: 0.6,
  },
  buttonText: {
    color: "#ffffff",
    fontSize: 16,
    fontWeight: "bold",
  },
  prediction: {
    fontSize: 22,
    fontWeight: "bold",
    marginBottom: 10,
    color: "#dc2626",
  },
});