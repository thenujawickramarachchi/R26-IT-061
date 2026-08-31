import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.onConnectionSaved,
  });

  final String baseUrl;
  final String apiKey;
  final Future<void> Function(String baseUrl, String apiKey) onConnectionSaved;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  bool _saving = false;
  bool _testing = false;
  String? _message;
  bool? _success;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.baseUrl);
    _keyController = TextEditingController(text: widget.apiKey);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl) {
      _urlController.text = widget.baseUrl;
    }
    if (oldWidget.apiKey != widget.apiKey) {
      _keyController.text = widget.apiKey;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _success = false;
        _message = 'Enter the backend URL.';
      });
      return;
    }
    setState(() => _saving = true);
    await widget.onConnectionSaved(_urlController.text, _keyController.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _success = true;
      _message = 'Connection settings saved.';
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _message = null;
    });
    try {
      final Map<String, dynamic> result = await ApiService(
        baseUrl: _urlController.text,
        apiKey: _keyController.text,
      ).health();
      if (!mounted) return;
      setState(() {
        _success = result['status'] == 'ok';
        _message = _success == true
            ? 'Backend connection successful.'
            : 'Backend returned an unexpected response.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _message = readableError(error);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Backend connection',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: appDarkTeal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The phone and backend computer must use the same Wi-Fi network for local testing.',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Backend server URL',
              hintText: 'http://127.0.0.1:8000',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key (optional)',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving...' : 'Save settings'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Testing...' : 'Test connection'),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _success == true
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _success == true ? Icons.check_circle : Icons.error,
                    color: _success == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_message!)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
