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
  static const Color red = Color(0xFFE53935);

  final TextEditingController casesController = TextEditingController();

  String? selectedArea;
  double rainfall = 20.0;
  double temperature = 28.0;

  bool isLoading = false;
  bool isAreasLoading = true;

  Map<String, dynamic>? result;
  String? errorMessage;
  String? areasError;
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
        areasError = 'Cannot load MOH areas. Please check the backend connection.';
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
        errorMessage = 'Please enter a valid weekly dengue case count.';
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
      return 'Cannot connect to the backend. Please check your internet connection and try again.';
    }

    if (error.contains('timeout')) {
      return 'The backend is taking too long to respond. Please try again shortly.';
    }

    return 'Unable to send the PHI alert right now. Please try again.';
  }

  Future<void> showAlertConfirmation() async {
    if (selectedArea == null) {
      setState(() => errorMessage = 'Please select an MOH area.');
      return;
    }

    final cases = int.tryParse(casesController.text.trim());

    if (cases == null || cases <= 0) {
      setState(() {
        errorMessage = 'Please enter a valid weekly dengue case count.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send PHI alert?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please confirm the details before sending.'),
              const SizedBox(height: 14),
              _dialogDetail('MOH Area', selectedArea!),
              _dialogDetail('Weekly Cases', '$cases'),
              _dialogDetail('Rainfall', '${rainfall.toStringAsFixed(1)} mm'),
              _dialogDetail(
                'Temperature',
                '${temperature.toStringAsFixed(1)} °C',
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
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send alert'),
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
          'PHI Alerts',
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
                    : const Icon(Icons.notification_important_rounded),
                label: Text(
                  isLoading ? 'SENDING...' : 'SEND PHI ALERT',
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
                    ? 'Alert Sent Successfully'
                    : noPhiOfficer
                        ? 'No Active PHI Officer Found'
                        : 'Alert Not Sent',
                message: emailSent
                    ? emailMessage
                    : noPhiOfficer
                        ? 'This MOH area does not have an active PHI officer email in the database.'
                        : emailMessage.isEmpty
                            ? 'No email response was received. Please try again.'
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
          colors: [Color(0xFFFFA726), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'PHI Alerts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Send a high-risk dengue alert to the active PHI officer.',
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
            'Alert Details',
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
                setState(() {
                  selectedArea = value;
                  result = null;
                  errorMessage = null;
                });
              },
            ),
          const SizedBox(height: 18),
          const Text(
            'Weekly Reported Dengue Cases',
            style: TextStyle(fontWeight: FontWeight.bold, color: title),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: casesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDecoration(
              icon: Icons.bug_report_rounded,
              hint: 'Example: 25',
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
            max: 50,
            divisions: 50,
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