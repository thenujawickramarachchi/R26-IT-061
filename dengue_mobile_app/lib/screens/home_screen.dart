import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'recommendation_screen.dart';
import 'phi_warning_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void openScreen(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  static const Color bg = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static const Color title = Color(0xFF111827);
  static const Color sub = Color(0xFF6B7280);
  static const Color red = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(),
              const SizedBox(height: 22),
              _welcomeCard(),
              const SizedBox(height: 24),
              const Text(
                'Main Menu',
                style: TextStyle(
                  color: title,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose a function to continue',
                style: TextStyle(color: sub, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _menuCard(
                context,
                icon: Icons.dashboard_rounded,
                title: 'Dashboard',
                subtitle:
                    'View research summary, progress, dataset, and system flow.',
                color: Colors.lightBlue,
                screen: const DashboardScreen(),
              ),
              _menuCard(
                context,
                icon: Icons.psychology_alt_rounded,
                title: 'AI Recommendation',
                subtitle: 'Enter dengue data and get best intervention action.',
                color: red,
                screen: const RecommendationScreen(),
              ),
              _menuCard(
                context,
                icon: Icons.local_police_rounded,
                title: 'PHI Warning System',
                subtitle: 'Send warning email for high-risk dengue situations.',
                color: Colors.orange,
                screen: const PHIWarningScreen(),
              ),
              _menuCard(
                context,
                icon: Icons.info_outline_rounded,
                title: 'About Project',
                subtitle:
                    'View research details, component purpose, and future work.',
                color: Colors.green,
                screen: const AboutScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            color: red,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dengue RL Agent',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: title,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Mobile Decision Support System',
                style: TextStyle(fontSize: 13, color: sub),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _welcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFE53935), Color(0xFFFFA39E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: red.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -18,
            child: Icon(
              Icons.coronavirus_rounded,
              size: 115,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🦟 Dengue Intervention\nOptimization Agent',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'AI-powered mobile application for recommending dengue control interventions using Reinforcement Learning.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Q-Learning based decision support',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => openScreen(context, screen),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: HomeScreen.title,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: sub,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: sub, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}
