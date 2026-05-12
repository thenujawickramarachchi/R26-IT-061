import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class PHIWarningScreen extends StatefulWidget {
  const PHIWarningScreen({super.key});

  @override
  State<PHIWarningScreen> createState() => _PHIWarningScreenState();
}

class _PHIWarningScreenState extends State<PHIWarningScreen> {
  final TextEditingController casesController = TextEditingController();

  String selectedArea = 'Colombo';
  double rainfall = 20.0;
  double temperature = 28.0;

  bool isLoading = false;
  Map<String, dynamic>? result;
  String? errorMessage;

  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);

  final List<String> areas = [
    'Colombo',
    'Dehiwala',
    'Moratuwa',
    'Kotte',
    'Kaduwela',
    'Kesbewa',
    'Kolonnawa',
    'Maharagama',
    'Padukka',
    'Seethawaka',
    'Homagama',
    'Avissawella',
  ];

  Future<void> sendWarning() async {
    if (casesController.text.trim().isEmpty) {
      setState(() {
        errorMessage = 'Please enter dengue cases.';
      });
      return;
    }

    final int? parsedCases = int.tryParse(casesController.text.trim());

    if (parsedCases == null || parsedCases <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid dengue case count greater than 0.';
      });
      return;
    }

    final int cases = parsedCases;

    setState(() {
      isLoading = true;
      result = null;
      errorMessage = null;
    });

    try {
      final response = await ApiService.sendWarning(
        area: selectedArea,
        cases: cases,
        rainfall: rainfall,
        temperature: temperature,
      );

      setState(() {
        result = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void loadHighRiskSample() {
    setState(() {
      selectedArea = 'Colombo';
      casesController.text = '6000';
      rainfall = 20.0;
      temperature = 28.0;
      result = null;
      errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = result?['email'];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('PHI Warning System')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _warningHeader(),
            const SizedBox(height: 18),
            Card(
              color: card,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOH Area',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: title,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedArea,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_rounded),
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
                        setState(() => selectedArea = value!);
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Dengue Cases',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: title,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: casesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Example: 6000',
                        prefixIcon: Icon(Icons.bug_report_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Rainfall: ${rainfall.toStringAsFixed(1)} mm',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: title,
                      ),
                    ),
                    Slider(
                      value: rainfall,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      onChanged: (value) => setState(() => rainfall = value),
                    ),
                    Text(
                      'Temperature: ${temperature.toStringAsFixed(1)} °C',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: title,
                      ),
                    ),
                    Slider(
                      value: temperature,
                      min: 20,
                      max: 40,
                      divisions: 40,
                      onChanged: (value) => setState(() => temperature = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: loadHighRiskSample,
              icon: const Icon(Icons.science_rounded),
              label: const Text(
                'LOAD HIGH RISK SAMPLE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: isLoading ? null : sendWarning,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.notification_important_rounded),
              label: Text(isLoading ? 'Sending...' : 'SEND WARNING TO PHI'),
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
                color: email != null && email['sent'] == true
                    ? Colors.green
                    : Colors.orange,
                icon: email != null && email['sent'] == true
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                titleText: email != null && email['sent'] == true
                    ? 'Email Sent Successfully'
                    : 'Email Not Sent',
                message: email?['message'] ?? 'No email response received.',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warningHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_police_rounded, color: Colors.white, size: 42),
          SizedBox(height: 12),
          Text(
            'PHI Warning System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send urgent dengue risk warning email to the PHI officer.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
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
