import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/rl_api_service.dart';

class InterventionFeedbackScreen extends StatefulWidget {
  const InterventionFeedbackScreen({super.key});

  @override
  State<InterventionFeedbackScreen> createState() =>
      _InterventionFeedbackScreenState();
}

class _InterventionFeedbackScreenState extends State<InterventionFeedbackScreen> {
  static const Color _background = Color(0xFFF5F7FA);
  static const Color _ink = Color(0xFF172033);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);

  static const Color _navy = Color(0xFF12355B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _skyBlue = Color(0xFF0EA5E9);
  static const Color _teal = Color(0xFF007C83);
  static const Color _success = Color(0xFF15803D);
  static const Color _danger = Color(0xFFDC2626);

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
            'Could not load saved advisory records. Please check your internet connection and try again.';
      });
    }
  }

  int _asInt(dynamic value) {
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  String _text(dynamic value, [String fallback = '-']) {
    final valueText = '$value';

    return value == null || valueText.isEmpty || valueText == 'null'
        ? fallback
        : valueText;
  }

  String _areaOf(Map<String, dynamic> warning) {
    return _text(warning['moh_area_name'] ?? warning['area']);
  }

  Map<String, dynamic>? get _selectedWarning {
    for (final warning in _warnings) {
      if (_asInt(warning['id']) == _selectedWarningId) {
        return warning;
      }
    }

    return null;
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
        'Select a saved advisory and enter valid follow-up cases and days.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save intervention follow-up?'),
            content: Text(
              'MOH Area: ${_areaOf(warning)}\n'
              'Action: ${_text(warning['recommended_action'])}\n'
              'Cases before: ${_asInt(warning['dengue_cases'])}\n'
              'Cases after: $casesAfter\n'
              'Outcome: ${_outcome.replaceAll('_', ' ')}\n\n'
              'This follow-up outcome will be saved and used by the backend learning workflow.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _submitting = true;
      _result = null;
    });

    try {
      final response = await ApiService.submitFeedback(
        warningHistoryId: _asInt(warning['id']),
        casesAfter: casesAfter,
        followUpDays: followUpDays,
        outcomeStatus: _outcome,
        feedbackNotes: _notesController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _result = response;
      });

      _showMessage('Follow-up outcome saved successfully.');
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Follow-up could not be saved. Please try again.',
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
        backgroundColor: isError ? _danger : _teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
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
          colors: [_navy, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.published_with_changes_outlined,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 12),
          Text(
            'Record intervention outcome',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Record PHI follow-up outcomes after an intervention has been completed.',
            style: TextStyle(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return _messageCard(
      icon: Icons.cloud_off_outlined,
      color: _blue,
      text: _error!,
      action: TextButton.icon(
        onPressed: _loadWarnings,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _emptyCard() {
    return _messageCard(
      icon: Icons.history_toggle_off_rounded,
      color: _blue,
      text: 'No saved PHI advisory records are available yet.',
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
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _ink,
                height: 1.35,
              ),
            ),
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
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow-up Details',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select the original advisory and enter the follow-up outcome.',
            style: TextStyle(
              color: _muted,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            value: _selectedWarningId,
            isExpanded: true,
            decoration: _decoration(
              'Original advisory record',
              Icons.campaign_outlined,
            ),
            hint: const Text('Select a saved PHI advisory'),
            items: _warnings.map((warning) {
              final area = _areaOf(warning);
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration(
              'Follow-up reported cases',
              Icons.monitor_heart_outlined,
              hint: 'Example: 1800',
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _daysController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration(
              'Follow-up period (days)',
              Icons.calendar_month_outlined,
              hint: 'Example: 14',
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _outcome,
            decoration: _decoration(
              'Observed outcome',
              Icons.analytics_outlined,
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
              Icons.note_alt_outlined,
              hint: 'Example: Fumigation completed and cases reduced.',
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_areaOf(warning)} • ${_text(warning['risk_level'])}',
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Recommended action: ${_text(warning['recommended_action'])}',
            style: const TextStyle(color: _muted),
          ),
          Text(
            'Cases before: ${_asInt(warning['dengue_cases'])}',
            style: const TextStyle(color: _muted),
          ),
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
      prefixIcon: Icon(icon, color: _blue),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _border),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
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
            : const Icon(Icons.save_outlined),
        label: Text(
          _submitting ? 'SAVING OUTCOME...' : 'SAVE FOLLOW-UP OUTCOME',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _successCard(Map<String, dynamic> response) {
    final reward = response['reward'] ?? 0;
    final updated = response['q_table_updated'] == true;

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
              Icon(
                Icons.check_circle_outline_rounded,
                color: _success,
              ),
              SizedBox(width: 9),
              Text(
                'Follow-up saved successfully',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Outcome reward: $reward',
            style: const TextStyle(color: _ink),
          ),
          const SizedBox(height: 3),
          Text(
            updated
                ? 'Q-learning table update completed.'
                : 'Outcome saved for review.',
            style: const TextStyle(
              color: _success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}