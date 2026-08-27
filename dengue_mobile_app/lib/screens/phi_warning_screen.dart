import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class PHIWarningScreen extends StatefulWidget {
  const PHIWarningScreen({super.key});

  @override
  State<PHIWarningScreen> createState() => _PHIWarningScreenState();
}

class _PHIWarningScreenState extends State<PHIWarningScreen> {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);
  static const Color red = Color(0xFF2563EB);

  final TextEditingController casesController = TextEditingController();

  String? selectedArea;
  double rainfall = 20.0;
  double temperature = 28.0;

  bool isLoading = false;
  bool isAreasLoading = true;
  bool isWeatherLoading = false;

  Map<String, dynamic>? result;
  Map<String, dynamic>? weatherResult;

  String? errorMessage;
  String? areasError;
  String? weatherError;

  List<String> areas = [];

  @override
  void initState() {
    super.initState();
    loadMohAreas();
  }

  @override
  void dispose() {
    casesController.dispose();
    super.dispose();
  }

  Future<void> loadMohAreas() async {
    setState(() {
      isAreasLoading = true;
      areasError = null;
    });

    try {
      final loadedAreas = await ApiService.getMohAreas();

      if (!mounted) return;

      setState(() {
        areas = loadedAreas;
        isAreasLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isAreasLoading = false;
        areasError =
            'Cannot load MOH areas. Please check the hosted API connection.';
      });
    }
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> loadAreaWeather(String area) async {
    setState(() {
      isWeatherLoading = true;
      weatherResult = null;
      weatherError = null;
    });

    try {
      final response = await ApiService.getAreaWeather(area: area);

      final loadedRainfall = _toDouble(response['rainfall'], rainfall);
      final loadedTemperature = _toDouble(response['temperature'], temperature);

      if (!mounted) return;

      setState(() {
        weatherResult = response;
        rainfall = loadedRainfall.clamp(0.0, 150.0).toDouble();
        temperature = loadedTemperature.clamp(20.0, 40.0).toDouble();
        isWeatherLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isWeatherLoading = false;
        weatherError =
            'Dataset weather context is unavailable. You can enter rainfall and temperature manually.';
      });
    }
  }

  Future<void> sendAlert() async {
    if (selectedArea == null) {
      setState(() => errorMessage = 'Please select an MOH area.');
      return;
    }

    final cases = int.tryParse(casesController.text.trim());

    if (cases == null || cases <= 0) {
      setState(() {
        errorMessage =
            'Please enter a valid dengue case value for the forecast assessment.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      result = null;
      errorMessage = null;
    });

    try {
      final response = await ApiService.sendWarning(
        area: selectedArea!,
        cases: cases,
        rainfall: rainfall,
        temperature: temperature,
      );

      if (!mounted) return;

      setState(() {
        result = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = friendlyWarningError(e.toString());
      });
    }
  }

  String friendlyWarningError(String rawError) {
    final error = rawError.toLowerCase();

    if (error.contains('socketexception') ||
        error.contains('failed host lookup') ||
        error.contains('cannot connect')) {
      return 'Cannot connect to the hosted API. Please check your internet connection and try again.';
    }

    if (error.contains('timeout')) {
      return 'The hosted API is taking too long to respond. Please try again shortly.';
    }

    return 'Unable to create the PHI review alert right now. Please try again.';
  }

  Future<void> showAlertConfirmation() async {
    if (selectedArea == null) {
      setState(() => errorMessage = 'Please select an MOH area.');
      return;
    }

    final cases = int.tryParse(casesController.text.trim());

    if (cases == null || cases <= 0) {
      setState(() {
        errorMessage =
            'Please enter a valid dengue case value for the forecast assessment.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create PHI review alert?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please confirm the forecast assessment details before creating an advisory.',
              ),
              const SizedBox(height: 14),
              _dialogDetail('MOH Area', selectedArea!),
              _dialogDetail('Assessment Cases', '$cases'),
              _dialogDetail('Rainfall', '${rainfall.toStringAsFixed(1)} mm'),
              _dialogDetail(
                'Temperature',
                '${temperature.toStringAsFixed(1)} °C',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Forecast-based advisory: PHI review is required before operational action.',
                  style: TextStyle(
                    color: title,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Recipient: active PHI officer registered for $selectedArea.',
                style: const TextStyle(color: sub, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.fact_check_rounded),
              label: const Text('Create alert'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await sendAlert();
    }
  }

  Widget _dialogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = result?['email'];
    final emailSent = email != null && email['sent'] == true;
    final emailMessage = (email?['message'] ?? '').toString();
    final noPhiOfficer =
        emailMessage.toLowerCase().contains('no phi officer');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: title,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Forecast-based PHI Alert',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _alertHeader(),
            const SizedBox(height: 18),
            _inputCard(),
            const SizedBox(height: 16),
            _forecastDisclaimer(),
            const SizedBox(height: 16),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : showAlertConfirmation,
                icon: isLoading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fact_check_rounded),
                label: Text(
                  isLoading
                      ? 'CREATING ALERT...'
                      : 'CREATE PHI REVIEW ALERT',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _statusCard(
                color: Colors.red,
                icon: Icons.error_outline_rounded,
                message: errorMessage!,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 18),
              _statusCard(
                color: emailSent
                    ? Colors.green
                    : noPhiOfficer
                        ? Colors.red
                        : Colors.orange,
                icon: emailSent
                    ? Icons.check_circle_outline_rounded
                    : noPhiOfficer
                        ? Icons.person_off_outlined
                        : Icons.warning_amber_rounded,
                titleText: emailSent
                    ? 'Forecast Alert Sent for PHI Review'
                    : noPhiOfficer
                        ? 'No Active PHI Officer Found'
                        : 'Forecast Alert Saved; Delivery Pending',
                message: emailSent
                    ? emailMessage
                    : noPhiOfficer
                        ? 'This MOH area does not have an active PHI officer email in the database.'
                        : emailMessage.isEmpty
                            ? 'The alert record was processed, but no email delivery response was received.'
                            : emailMessage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
  colors: [Color(0xFF12355B), Color(0xFF2563EB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fact_check_rounded,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'Forecast-based PHI Alert',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create an early-warning advisory for PHI review before operational action.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forecast Alert Details',
            style: TextStyle(
              color: title,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'MOH Area',
            style: TextStyle(fontWeight: FontWeight.bold, color: title),
          ),
          const SizedBox(height: 8),
          if (isAreasLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Loading MOH areas...'),
                ],
              ),
            )
          else if (areasError != null)
            _statusCard(
              color: Colors.red,
              icon: Icons.error_outline_rounded,
              titleText: 'MOH Areas Unavailable',
              message: areasError!,
            )
          else
            DropdownButtonFormField<String>(
              value: selectedArea,
              isExpanded: true,
              hint: const Text('Select MOH area'),
              decoration: _fieldDecoration(
                icon: Icons.location_on_rounded,
              ),
              items: areas
                  .map(
                    (area) => DropdownMenuItem(
                      value: area,
                      child: Text(area),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedArea = value;
                  result = null;
                  errorMessage = null;
                });

                loadAreaWeather(value);
              },
            ),
          const SizedBox(height: 14),
          _weatherContextCard(),
          const SizedBox(height: 18),
          const Text(
            'Dengue Cases for Forecast Assessment',
            style: TextStyle(fontWeight: FontWeight.bold, color: title),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: casesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              icon: Icons.bug_report_rounded,
              hint: 'Example: 500',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Rainfall: ${rainfall.toStringAsFixed(1)} mm',
            style: const TextStyle(fontWeight: FontWeight.bold, color: title),
          ),
          Slider(
            value: rainfall,
            min: 0,
            max: 150,
            divisions: 150,
            activeColor: red,
            onChanged: (value) => setState(() => rainfall = value),
          ),
          Text(
            'Temperature: ${temperature.toStringAsFixed(1)} °C',
            style: const TextStyle(fontWeight: FontWeight.bold, color: title),
          ),
          Slider(
            value: temperature,
            min: 20,
            max: 40,
            divisions: 40,
            activeColor: red,
            onChanged: (value) => setState(() => temperature = value),
          ),
          const SizedBox(height: 4),
          const Text(
            'You can adjust the available dataset context values before creating the advisory.',
            style: TextStyle(color: sub, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _forecastDisclaimer() {
  return Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFBFDBFE),
      ),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: Color(0xFF2563EB),
          size: 25,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Forecast-based decision support: this advisory uses assessment inputs and latest available project dataset context. It does not confirm a current outbreak. PHI review is required before operational action.',
            style: TextStyle(
              color: title,
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _weatherContextCard() {
    if (isWeatherLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading available dataset weather context...'),
          ],
        ),
      );
    }

    if (weatherError != null) {
      return _statusCard(
        color: Colors.orange,
        icon: Icons.cloud_off_rounded,
        titleText: 'Dataset Weather Context Unavailable',
        message: weatherError!,
      );
    }

    if (weatherResult == null) {
      return _statusCard(
        color: Colors.blue,
        icon: Icons.cloud_outlined,
        titleText: 'Latest Available Dataset Weather Context',
        message:
            'Select an MOH area to auto-fill available rainfall and temperature context.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Latest available project dataset weather context loaded. Rainfall and temperature were auto-filled below.',
              style: TextStyle(
                color: title,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: red),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _statusCard({
    required Color color,
    required IconData icon,
    required String message,
    String? titleText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.30)),

      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titleText == null ? message : '$titleText\n$message',
              style: const TextStyle(height: 1.45, color: title),
            ),
          ),
        ],
      ),
    );
  }
}