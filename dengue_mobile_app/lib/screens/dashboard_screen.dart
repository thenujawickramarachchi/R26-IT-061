import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _background = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF6B7280);
  static const _red = Color(0xFFE53935);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _warnings = [];
  List<String> _areas = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getWarningHistory(limit: 20),
        ApiService.getMohAreas(),
      ]);
      if (!mounted) return;
      setState(() {
        _warnings = results[0] as List<Map<String, dynamic>>;
        _areas = results[1] as List<String>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Dashboard data is unavailable. Check the backend connection and refresh.';
      });
    }
  }

  bool _isHigh(Map<String, dynamic> warning) =>
      '${warning['risk_level']}'.toUpperCase() == 'HIGH';

  bool _emailSent(Map<String, dynamic> warning) {
    final value = warning['email_sent'];
    return value == true || '$value'.toLowerCase() == 'true';
  }

  String _text(dynamic value, [String fallback = 'Not available']) {
    final text = '$value';
    return value == null || text == 'null' || text.isEmpty ? fallback : text;
  }

  String _dateText(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return 'Recent';
    final month = _monthName(parsed.month);
    return '${parsed.day} $month, ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final highCount = _warnings.where(_isHigh).length;
    final sentCount = _warnings.where(_emailSent).length;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: true,
        title: const Text('Operations Dashboard', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _loadDashboard, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
          children: [
            _hero(),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 70),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _errorCard()
            else ...[
              const Text('Current activity', style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Live summary from warning and MOH records.', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _metric('$highCount', 'High-risk alerts', Icons.warning_amber_rounded, _red)),
                const SizedBox(width: 10),
                Expanded(child: _metric('$sentCount', 'Emails sent', Icons.mark_email_read_rounded, const Color(0xFF16A34A))),
                const SizedBox(width: 10),
                Expanded(child: _metric('${_areas.length}', 'MOH areas', Icons.location_city_rounded, const Color(0xFF0284C7))),
              ]),
              const SizedBox(height: 27),
              const Text('Recent alerts', style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Most recent warning records saved by the system.', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 14),
              if (_warnings.isEmpty) _emptyState() else ..._warnings.take(4).map(_alertCard),
              const SizedBox(height: 14),
              _dataNotice(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF746F)]),
          boxShadow: [BoxShadow(color: _red.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        child: const Row(children: [
          Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 39),
          SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dengue response overview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)),
            SizedBox(height: 6),
            Text('Monitor risk alerts, PHI email delivery, and area coverage.', style: TextStyle(color: Colors.white, height: 1.35)),
          ])),
        ]),
      );

  Widget _metric(String value, String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 21)),
          const SizedBox(height: 3),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 10.5, height: 1.2)),
        ]),
      );

  Widget _alertCard(Map<String, dynamic> warning) {
    final high = _isHigh(warning);
    final sent = _emailSent(warning);
    final area = _text(warning['moh_area_name'], _text(warning['area'], 'MOH area'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: (high ? _red : const Color(0xFFF59E0B)).withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(high ? Icons.warning_rounded : Icons.info_outline_rounded, color: high ? _red : const Color(0xFFF59E0B))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(area, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(_text(warning['recommended_action']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_dateText(warning['created_at']), style: const TextStyle(color: _muted, fontSize: 11.5)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _pill(_text(warning['risk_level'], 'UNKNOWN'), high ? _red : const Color(0xFFF59E0B)),
            const SizedBox(height: 7),
            Icon(sent ? Icons.mark_email_read_rounded : Icons.email_outlined, color: sent ? const Color(0xFF16A34A) : _muted, size: 20),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Text(label.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10)),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: const Row(children: [
          Icon(Icons.history_toggle_off_rounded, color: _muted),
          SizedBox(width: 12),
          Expanded(child: Text('No alert records have been saved yet.', style: TextStyle(color: _muted))),
        ]),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFECACA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.wifi_off_rounded, color: _red), SizedBox(width: 9), Text('Dashboard unavailable', style: TextStyle(color: _ink, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: _muted, height: 1.35)),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _loadDashboard, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ]),
      );

  Widget _dataNotice() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(17)),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7)),
          SizedBox(width: 10),
          Expanded(child: Text('Pull down or use Refresh to load the latest backend records.', style: TextStyle(color: Color(0xFF1E3A5F), fontSize: 12.5, height: 1.3))),
        ]),
      );
}
