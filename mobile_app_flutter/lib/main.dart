import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DenguePredictionApp());
}

class DenguePredictionApp extends StatelessWidget {
  const DenguePredictionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Outbreak Prediction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
      ),
      home: const PredictionScreen(),
    );
  }
}

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  bool isLoading = false;
  bool showAdvanced = false;
  Map<String, dynamic>? result;

  // Change this IP according to your current laptop IPv4 address.
  final String apiUrl = 'http://10.240.145.242:8000/predict';

final Map<String, TextEditingController> controllers = {
  'year': TextEditingController(text: '2025'),
  'week': TextEditingController(text: '53'),
  'month': TextEditingController(text: '12'),
  'temp_max_c': TextEditingController(text: '33.020325'),
  'temp_min_c': TextEditingController(text: '25.080488'),
  'temp_mean_c': TextEditingController(text: '28.727642'),
  'feelslikemax': TextEditingController(text: '37.878949'),
  'feelslikemin': TextEditingController(text: '26.193496'),
  'feelslike': TextEditingController(text: '31.772358'),
  'dew': TextEditingController(text: '21.752033'),
  'humidity_pct': TextEditingController(text: '69.297561'),
  'rainfall_mm': TextEditingController(text: '6.025293'),
  'precipprob': TextEditingController(text: '37.398374'),
  'precipcover': TextEditingController(text: '2.676667'),
  'wind_speed_kmh': TextEditingController(text: '16.504878'),
  'winddir': TextEditingController(text: '183.544715'),
  'sealevelpressure': TextEditingController(text: '1003.359350'),
  'cloudcover': TextEditingController(text: '50.208130'),
  'visibility': TextEditingController(text: '2.991057'),
  'solarradiation': TextEditingController(text: '225.421951'),
  'solarenergy': TextEditingController(text: '19.480488'),
  'uvindex': TextEditingController(text: '7.593496'),
};

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void fillSampleData() {
    final sample = {
      'year': '2026',
      'week': '20',
      'month': '5',
      'temp_max_c': '31.2',
      'temp_min_c': '25.4',
      'temp_mean_c': '28.3',
      'feelslikemax': '36.0',
      'feelslikemin': '27.0',
      'feelslike': '31.2',
      'dew': '24.5',
      'humidity_pct': '82.0',
      'rainfall_mm': '45.0',
      'precipprob': '80.0',
      'precipcover': '12.0',
      'wind_speed_kmh': '15.3',
      'winddir': '210.0',
      'sealevelpressure': '1010.0',
      'cloudcover': '75.0',
      'visibility': '9.5',
      'solarradiation': '180.0',
      'solarenergy': '15.0',
      'uvindex': '6.0',
    };

    sample.forEach((key, value) {
      controllers[key]?.text = value;
    });

    setState(() {
      result = null;
    });
  }

  void clearForm() {
    for (final controller in controllers.values) {
      controller.clear();
    }

    setState(() {
      result = null;
    });
  }

  double _doubleValue(String key) {
    return double.tryParse(controllers[key]!.text.trim()) ?? 0.0;
  }

  int _intValue(String key) {
    return int.tryParse(controllers[key]!.text.trim()) ?? 0;
  }

  bool validateRequiredFields() {
    final requiredFields = [
      'year',
      'week',
      'month',
      'temp_max_c',
      'temp_min_c',
      'temp_mean_c',
      'humidity_pct',
      'rainfall_mm',
      'wind_speed_kmh',
    ];

    for (final field in requiredFields) {
      if (controllers[field]!.text.trim().isEmpty) {
        showMessage('Please fill all required fields.');
        return false;
      }
    }

    return true;
  }

  Future<void> predictOutbreak() async {
    if (!validateRequiredFields()) return;

    setState(() {
      isLoading = true;
      result = null;
    });

    final inputData = {
      'year': _intValue('year'),
      'week': _intValue('week'),
      'month': _intValue('month'),
      'temp_max_c': _doubleValue('temp_max_c'),
      'temp_min_c': _doubleValue('temp_min_c'),
      'temp_mean_c': _doubleValue('temp_mean_c'),
      'feelslikemax': _doubleValue('feelslikemax'),
      'feelslikemin': _doubleValue('feelslikemin'),
      'feelslike': _doubleValue('feelslike'),
      'dew': _doubleValue('dew'),
      'humidity_pct': _doubleValue('humidity_pct'),
      'rainfall_mm': _doubleValue('rainfall_mm'),
      'precipprob': _doubleValue('precipprob'),
      'precipcover': _doubleValue('precipcover'),
      'wind_speed_kmh': _doubleValue('wind_speed_kmh'),
      'winddir': _doubleValue('winddir'),
      'sealevelpressure': _doubleValue('sealevelpressure'),
      'cloudcover': _doubleValue('cloudcover'),
      'visibility': _doubleValue('visibility'),
      'solarradiation': _doubleValue('solarradiation'),
      'solarenergy': _doubleValue('solarenergy'),
      'uvindex': _doubleValue('uvindex'),
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(inputData),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      setState(() {
        result = jsonDecode(response.body);
      });
    } catch (e) {
      showMessage('Prediction API error. Check backend and IP address.');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color getRiskColor(String level) {
    if (level == 'High') return Colors.red;
    if (level == 'Medium') return Colors.orange;
    return Colors.green;
  }

  Widget buildInput({
    required String label,
    required String keyName,
    required IconData icon,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controllers[keyName],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: requiredField ? '$label *' : label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffd8dee9)),
          ),
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget buildProbabilityBar(String label, double value, Color color) {
    final percentage = (value * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text('$percentage%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResultCard() {
    if (result == null) return const SizedBox.shrink();

    final level = result!['predicted_outbreak_level'] as String;
    final probabilities = result!['probabilities'] as Map<String, dynamic>;
    final riskColor = getRiskColor(level);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionTitle('Prediction Result', Icons.analytics),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: riskColor),
                ),
                child: Text(
                  '$level Risk',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Model Used: ${result!['model_used']}',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 18),
            const Text(
              'Class Probabilities',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            buildProbabilityBar(
              'High',
              (probabilities['High'] ?? 0).toDouble(),
              Colors.red,
            ),
            buildProbabilityBar(
              'Medium',
              (probabilities['Medium'] ?? 0).toDouble(),
              Colors.orange,
            ),
            buildProbabilityBar(
              'Low',
              (probabilities['Low'] ?? 0).toDouble(),
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMainInputs() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            buildSectionTitle('Main Details', Icons.dashboard),
            const SizedBox(height: 16),
            buildInput(
              label: 'Year',
              keyName: 'year',
              icon: Icons.calendar_month,
              requiredField: true,
            ),
            buildInput(
              label: 'Week',
              keyName: 'week',
              icon: Icons.view_week,
              requiredField: true,
            ),
            buildInput(
              label: 'Month',
              keyName: 'month',
              icon: Icons.date_range,
              requiredField: true,
            ),
            buildInput(
              label: 'Mean Temperature',
              keyName: 'temp_mean_c',
              icon: Icons.thermostat,
              requiredField: true,
            ),
            buildInput(
              label: 'Humidity %',
              keyName: 'humidity_pct',
              icon: Icons.water_drop,
              requiredField: true,
            ),
            buildInput(
              label: 'Rainfall mm',
              keyName: 'rainfall_mm',
              icon: Icons.cloudy_snowing,
              requiredField: true,
            ),
            buildInput(
              label: 'Wind Speed km/h',
              keyName: 'wind_speed_kmh',
              icon: Icons.air,
              requiredField: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAdvancedInputs() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  showAdvanced = !showAdvanced;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Advanced Weather Details',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ],
              ),
            ),
            if (showAdvanced) ...[
              const SizedBox(height: 16),
              buildInput(
                label: 'Max Temperature',
                keyName: 'temp_max_c',
                icon: Icons.thermostat,
              ),
              buildInput(
                label: 'Min Temperature',
                keyName: 'temp_min_c',
                icon: Icons.thermostat,
              ),
              buildInput(
                label: 'Feels Like Max',
                keyName: 'feelslikemax',
                icon: Icons.device_thermostat,
              ),
              buildInput(
                label: 'Feels Like Min',
                keyName: 'feelslikemin',
                icon: Icons.device_thermostat,
              ),
              buildInput(
                label: 'Feels Like',
                keyName: 'feelslike',
                icon: Icons.device_thermostat,
              ),
              buildInput(
                label: 'Dew',
                keyName: 'dew',
                icon: Icons.opacity,
              ),
              buildInput(
                label: 'Precipitation Probability',
                keyName: 'precipprob',
                icon: Icons.water,
              ),
              buildInput(
                label: 'Precipitation Cover',
                keyName: 'precipcover',
                icon: Icons.cloud,
              ),
              buildInput(
                label: 'Wind Direction',
                keyName: 'winddir',
                icon: Icons.explore,
              ),
              buildInput(
                label: 'Sea Level Pressure',
                keyName: 'sealevelpressure',
                icon: Icons.speed,
              ),
              buildInput(
                label: 'Cloud Cover',
                keyName: 'cloudcover',
                icon: Icons.cloud_queue,
              ),
              buildInput(
                label: 'Visibility',
                keyName: 'visibility',
                icon: Icons.visibility,
              ),
              buildInput(
                label: 'Solar Radiation',
                keyName: 'solarradiation',
                icon: Icons.wb_sunny,
              ),
              buildInput(
                label: 'Solar Energy',
                keyName: 'solarenergy',
                icon: Icons.energy_savings_leaf,
              ),
              buildInput(
                label: 'UV Index',
                keyName: 'uvindex',
                icon: Icons.sunny,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : predictOutbreak,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.health_and_safety),
            label: Text(
              isLoading ? 'Predicting...' : 'Predict Outbreak Level',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: fillSampleData,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Sample'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: clearForm,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff00897b), Color(0xff26a69a)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety, color: Colors.white, size: 42),
          SizedBox(height: 12),
          Text(
            'Dengue Outbreak Prediction',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Enter weather and time details to predict dengue outbreak risk level.',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              buildHeader(),
              const SizedBox(height: 18),
              buildMainInputs(),
              buildAdvancedInputs(),
              const SizedBox(height: 18),
              buildActionButtons(),
              buildResultCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}