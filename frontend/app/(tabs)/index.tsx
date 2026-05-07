import React, { useState } from "react";
import {
  Alert,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

export default function HomeScreen() {
  const [result, setResult] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const API_URL = "http://10.204.120.47:8000/predict";

  const [formData, setFormData] = useState({
    year: "2026",
    week: "20",
    month: "5",
    temp_max_c: "31.2",
    temp_min_c: "25.4",
    temp_mean_c: "28.3",
    feelslikemax: "36.0",
    feelslikemin: "27.0",
    feelslike: "31.2",
    dew: "24.5",
    humidity_pct: "82.0",
    rainfall_mm: "45.0",
    precipprob: "80.0",
    precipcover: "12.0",
    wind_speed_kmh: "15.3",
    winddir: "210.0",
    sealevelpressure: "1010.0",
    cloudcover: "75.0",
    visibility: "9.5",
    solarradiation: "180.0",
    solarenergy: "15.0",
    uvindex: "6.0",
  });

  const updateField = (field: string, value: string) => {
    setFormData({
      ...formData,
      [field]: value,
    });
  };

  const predictOutbreak = async () => {
    try {
      setLoading(true);
      setResult(null);

      const inputData = {
        year: parseInt(formData.year),
        week: parseInt(formData.week),
        month: parseInt(formData.month),
        temp_max_c: parseFloat(formData.temp_max_c),
        temp_min_c: parseFloat(formData.temp_min_c),
        temp_mean_c: parseFloat(formData.temp_mean_c),
        feelslikemax: parseFloat(formData.feelslikemax),
        feelslikemin: parseFloat(formData.feelslikemin),
        feelslike: parseFloat(formData.feelslike),
        dew: parseFloat(formData.dew),
        humidity_pct: parseFloat(formData.humidity_pct),
        rainfall_mm: parseFloat(formData.rainfall_mm),
        precipprob: parseFloat(formData.precipprob),
        precipcover: parseFloat(formData.precipcover),
        wind_speed_kmh: parseFloat(formData.wind_speed_kmh),
        winddir: parseFloat(formData.winddir),
        sealevelpressure: parseFloat(formData.sealevelpressure),
        cloudcover: parseFloat(formData.cloudcover),
        visibility: parseFloat(formData.visibility),
        solarradiation: parseFloat(formData.solarradiation),
        solarenergy: parseFloat(formData.solarenergy),
        uvindex: parseFloat(formData.uvindex),
      };

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

  const renderInput = (label: string, field: string) => (
    <View style={styles.inputGroup}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        style={styles.input}
        value={formData[field as keyof typeof formData]}
        onChangeText={(value) => updateField(field, value)}
        keyboardType="numeric"
        placeholder={label}
      />
    </View>
  );

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={styles.container}>
        <Text style={styles.title}>Dengue Outbreak Prediction</Text>

        <View style={styles.card}>
          <Text style={styles.subtitle}>Enter Weather and Time Details</Text>

          {renderInput("Year", "year")}
          {renderInput("Week", "week")}
          {renderInput("Month", "month")}
          {renderInput("Max Temperature", "temp_max_c")}
          {renderInput("Min Temperature", "temp_min_c")}
          {renderInput("Mean Temperature", "temp_mean_c")}
          {renderInput("Feels Like Max", "feelslikemax")}
          {renderInput("Feels Like Min", "feelslikemin")}
          {renderInput("Feels Like", "feelslike")}
          {renderInput("Dew", "dew")}
          {renderInput("Humidity %", "humidity_pct")}
          {renderInput("Rainfall mm", "rainfall_mm")}
          {renderInput("Precipitation Probability", "precipprob")}
          {renderInput("Precipitation Cover", "precipcover")}
          {renderInput("Wind Speed km/h", "wind_speed_kmh")}
          {renderInput("Wind Direction", "winddir")}
          {renderInput("Sea Level Pressure", "sealevelpressure")}
          {renderInput("Cloud Cover", "cloudcover")}
          {renderInput("Visibility", "visibility")}
          {renderInput("Solar Radiation", "solarradiation")}
          {renderInput("Solar Energy", "solarenergy")}
          {renderInput("UV Index", "uvindex")}
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
    marginBottom: 14,
    color: "#111827",
  },
  inputGroup: {
    marginBottom: 12,
  },
  label: {
    fontSize: 14,
    fontWeight: "600",
    marginBottom: 4,
    color: "#374151",
  },
  input: {
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 8,
    padding: 10,
    fontSize: 15,
    backgroundColor: "#ffffff",
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
  text: {
    fontSize: 16,
    marginBottom: 4,
    color: "#111827",
  },
});