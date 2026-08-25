import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InterventionFeedbackScreen extends StatefulWidget {
  const InterventionFeedbackScreen({super.key});

  @override
  State<InterventionFeedbackScreen> createState() =>
      _InterventionFeedbackScreenState();
}

class _InterventionFeedbackScreenState extends State<InterventionFeedbackScreen> {
  static const Color _red = Color(0xFFE53935);
  static const Color _ink = Color(0xFF111827);

  final _casesAfterController = TextEditingController();
  final _daysController = TextEditingController(text: '14');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _warnings = [];
  int? _selectedWarningId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String _outcome = 'improved';
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  @override
  void dispose() {
    _casesAfterController.dispose();
    _daysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWarnings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final warnings = await ApiService.getWarningHistory(limit: 50);

      if (!mounted) return;

      final uniqueWarnings = <int, Map<String, dynamic>>{};

      for (final warning in warnings) {
        final id = _asInt(warning['id']);

        if (id > 0) {
          uniqueWarnings[id] = warning;
        }
      }

      setState(() {
        _warnings = uniqueWarnings.values.toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Could not load warning records. Ensure the local backend is running.';
      });
    }
  }

  int _asInt(dynamic value) {
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  Map<String, dynamic>? get _selectedWarning {
    for (final warning in _warnings) {
      if (_asInt(warning['id']) == _selectedWarningId) {
        return warning;
      }
    }

    return null;
  }

  String _text(dynamic value, [String fallback = '-']) {
    final valueText = '$value';

    return value == null || valueText.isEmpty || valueText == 'null'
        ? fallback
        : valueText;
  }

  Future<void> _submit() async {
    final warning = _selectedWarning;
    final casesAfter = int.tryParse(_casesAfterController.text.trim());
    final followUpDays = int.tryParse(_daysController.text.trim());

    if (warning == null ||
        casesAfter == null ||
        casesAfter < 0 ||
        followUpDays == null ||
        followUpDays <= 0) {
      _showMessage(
        'Select a warning and enter valid follow-up cases and days.',
        isError: true,
      );
      return;
    }

    final shouldSubmit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save intervention follow-up?'),
            content: Text(
              'Action: ${_text(warning['recommended_action'])}\n'
              'Cases before: ${_asInt(warning['dengue_cases'])}\n'
              'Cases after: $casesAfter\n'
              'Outcome: ${_outcome.replaceAll('_', ' ')}\n\n'
              'This follow-up outcome will be saved for response planning.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldSubmit) return;

    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final result = await ApiService.submitFeedback(
        warningHistoryId: _asInt(warning['id']),
        casesAfter: casesAfter,
        followUpDays: followUpDays,
        outcomeStatus: _outcome,
        feedbackNotes: _notesController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _result = result);

      _showMessage('Follow-up outcome saved successfully.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Follow-up could not be saved. Check the backend connection.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Intervention Follow-up',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWarnings,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  if (_error != null) _errorCard(),
                  if (_warnings.isEmpty && _error == null) _emptyCard(),
                  if (_warnings.isNotEmpty) ...[
                    _formCard(),
                    const SizedBox(height: 18),
                    _submitButton(),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 18),
                    _successCard(_result!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5CE7), Color(0xFF9B8CFF)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.loop_rounded, color: Colors.white, size: 34),
          SizedBox(height: 12),
          Text(
            'Record intervention outcome',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Record the PHI follow-up outcome after an intervention has been completed.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return _messageCard(
      icon: Icons.wifi_off_rounded,
      color: Colors.red,
      text: _error!,
      action: TextButton.icon(
        onPressed: _loadWarnings,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _emptyCard() {
    return _messageCard(
      icon: Icons.history_toggle_off_rounded,
      color: Colors.orange,
      text: 'No saved alert records are available yet.',
    );
  }

  Widget _messageCard({
    required IconData icon,
    required Color color,
    required String text,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(height: 1.35)),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow-up Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select the original alert and enter the follow-up outcome.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            value: _selectedWarningId,
            isExpanded: true,
            decoration: _decoration(
              'Original alert record',
              Icons.campaign_rounded,
            ),
            hint: const Text('Select a saved PHI alert'),
            items: _warnings.map((warning) {
              final area = _text(warning['area']);
              final action = _text(warning['recommended_action']);

              return DropdownMenuItem<int>(
                value: _asInt(warning['id']),
                child: Text(
                  '$area — $action',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (warningId) {
              setState(() {
                _selectedWarningId = warningId;
                _result = null;

                final warning = _selectedWarning;

                if (warning != null) {
                  _casesAfterController.text =
                      _asInt(warning['dengue_cases']).toString();
                }
              });
            },
          ),
          if (_selectedWarning != null) ...[
            const SizedBox(height: 14),
            _warningSummary(_selectedWarning!),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _casesAfterController,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'Follow-up reported cases',
              Icons.monitor_heart_rounded,
              hint: 'Example: 1800',
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            decoration: _decoration(
              'Follow-up period (days)',
              Icons.calendar_month_rounded,
              hint: 'Example: 14',
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _outcome,
            decoration: _decoration(
              'Observed outcome',
              Icons.insights_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: 'improved',
                child: Text('Improved'),
              ),
              DropdownMenuItem(
                value: 'no_change',
                child: Text('No change'),
              ),
              DropdownMenuItem(
                value: 'worsened',
                child: Text('Worsened'),
              ),
            ],
            onChanged: (value) {
              setState(() => _outcome = value ?? 'improved');
            },
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: _decoration(
              'PHI notes (optional)',
              Icons.note_alt_rounded,
              hint: 'Example: Fumigation completed and reported cases reduced.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningSummary(Map<String, dynamic> warning) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_text(warning['area'])} • ${_text(warning['risk_level'])}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text('Recommended action: ${_text(warning['recommended_action'])}'),
          Text('Cases before: ${_asInt(warning['dengue_cases'])}'),
        ],
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _red),
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

  Widget _submitButton() {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save_rounded),
        label: Text(
          _submitting ? 'SAVING OUTCOME...' : 'SAVE FOLLOW-UP OUTCOME',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _successCard(Map<String, dynamic> result) {
    final reward = result['reward'] ?? 0;
    final updated = result['q_table_updated'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green),
              SizedBox(width: 9),
              Text(
                'Follow-up saved successfully',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Outcome score: $reward'),
          Text(
            updated
                ? 'Response learning update completed.'
                : 'Outcome saved for review.',
          ),
        ],
      ),
    );
  }
}