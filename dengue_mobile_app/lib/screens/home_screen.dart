import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'recommendation_screen.dart';
import 'phi_warning_screen.dart';
import 'warning_history_screen.dart';
import 'intervention_feedback_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _background = Color(0xFFF7F8FA);
  static const _ink = Color(0xFF172033);
  static const _muted = Color(0xFF6B7280);
  static const _red = Color(0xFFE53935);

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
          children: [
            _header(),
            const SizedBox(height: 22),
            _noticeCard(),
            const SizedBox(height: 28),
            const Text('Operations', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 5),
            const Text('Select a task to support dengue response activities.', style: TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 17),
            _menuCard(context, icon: Icons.dashboard_rounded, title: 'Operations Dashboard', subtitle: 'Review current alerts, activity, and area information.', color: Color(0xFF0284C7), screen: const DashboardScreen()),
            _menuCard(context, icon: Icons.analytics_rounded, title: 'Risk Assessment', subtitle: 'Assess an MOH area and view recommended actions.', color: _red, screen: const RecommendationScreen()),
            _menuCard(context, icon: Icons.notifications_active_rounded, title: 'PHI Alerts', subtitle: 'Review and send high-risk dengue alerts to PHI officers.', color: Color(0xFFF59E0B), screen: const PHIWarningScreen()),
            _menuCard(context, icon: Icons.history_rounded, title: 'Alert History', subtitle: 'View saved alerts and email delivery status.', color: Color(0xFF7C3AED), screen: const WarningHistoryScreen()),
            _menuCard(context, icon: Icons.loop_rounded, title: 'Intervention Follow-up', subtitle: 'Record PHI outcomes to improve future decisions.', color: Color(0xFF4F46E5), screen: const InterventionFeedbackScreen()),
          ],
        ),
      ),
    );
  }

  Widget _header() => Row(children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: _red.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.health_and_safety_rounded, color: _red, size: 29)),
        const SizedBox(width: 13),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dengue Response', style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
          SizedBox(height: 3),
          Text('PHI and MOH decision support', style: TextStyle(color: _muted, fontSize: 13)),
        ])),
      ]);

  Widget _noticeCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF746F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: _red.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 9))],
        ),
        child: const Row(children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 34),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dengue response support', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('Assess local risk, coordinate PHI alerts, and record intervention outcomes.', style: TextStyle(color: Colors.white, height: 1.35)),
          ])),
        ]),
      );

  Widget _menuCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required Widget screen}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _open(context, screen),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(17)), child: Icon(icon, color: color, size: 29)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 27),
            ]),
          ),
        ),
      ),
    );
  }
}
