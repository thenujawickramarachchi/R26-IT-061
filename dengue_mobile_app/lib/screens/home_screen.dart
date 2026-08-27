import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'recommendation_screen.dart';
import 'phi_warning_screen.dart';
import 'warning_history_screen.dart';
import 'intervention_feedback_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color _background = Color(0xFFF5F7FA);
  static const Color _surface = Colors.white;
  static const Color _ink = Color(0xFF172033);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE4E7EC);

  static const Color _navy = Color(0xFF12355B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _skyBlue = Color(0xFF0EA5E9);
  static const Color _teal = Color(0xFF007C83);
  static const Color _indigo = Color(0xFF4F46E5);

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
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
            _supportCard(),
            const SizedBox(height: 28),
            const Text(
              'Operations',
              style: TextStyle(
                color: _ink,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Select a task to support dengue response activities.',
              style: TextStyle(
                color: _muted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 17),
            _menuCard(
              context,
              icon: Icons.space_dashboard_outlined,
              title: 'Operations Dashboard',
              subtitle: 'Review current alerts, activity, and area information.',
              color: _blue,
              screen: const DashboardScreen(),
            ),
            _menuCard(
              context,
              icon: Icons.analytics_outlined,
              title: 'Risk Assessment',
              subtitle: 'Assess an MOH area and view recommended actions.',
              color: _teal,
              screen: const RecommendationScreen(),
            ),
            _menuCard(
              context,
              icon: Icons.campaign_outlined,
              title: 'PHI Alerts',
              subtitle: 'Create forecast-based advisories for PHI review.',
              color: _skyBlue,
              screen: const PHIWarningScreen(),
            ),
            _menuCard(
              context,
              icon: Icons.history_outlined,
              title: 'Alert History',
              subtitle: 'View saved advisories and delivery status.',
              color: _navy,
              screen: const WarningHistoryScreen(),
            ),
            _menuCard(
              context,
              icon: Icons.published_with_changes_outlined,
              title: 'Intervention Follow-up',
              subtitle: 'Record PHI outcomes to improve future decisions.',
              color: _indigo,
              screen: const InterventionFeedbackScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.medical_services_outlined,
            color: _blue,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dengue Response',
                style: TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'PHI and MOH decision support',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _supportCard() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _navy.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            color: Colors.white,
            size: 34,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dengue response support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Assess forecast risk, coordinate PHI review alerts, and record intervention outcomes.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget screen,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(context, screen),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}