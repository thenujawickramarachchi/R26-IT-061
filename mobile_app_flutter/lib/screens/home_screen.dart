import 'package:flutter/material.dart';

import 'dengue_prediction_screen.dart';
import 'dashboard_screen.dart';
import 'trend_screen.dart';
import 'risk_map_screen.dart';
import 'explain_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dengue Health SL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI-Based Dengue Public Health Support System',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Select a module to continue.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 28),

              // ============================================================
              // DENGUE PREDICTION
              // ============================================================
              _FeatureCard(
                icon: Icons.analytics_rounded,
                title: 'Dengue Prediction',
                description:
                    'Predict Colombo District dengue outbreak risk and view selected MOH-area proxy risk context.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DenguePredictionScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ============================================================
              // DENGUE DASHBOARD
              // ============================================================
              _FeatureCard(
                icon: Icons.dashboard_rounded,
                title: 'Dengue Dashboard',
                description:
                    'View the current Colombo District dengue risk, prediction summary, and latest model information.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DashboardScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ============================================================
              // DENGUE TRENDS
              // ============================================================
              _FeatureCard(
                icon: Icons.show_chart_rounded,
                title: 'Dengue Trends',
                description:
                    'Explore recent weekly dengue risk and prediction trends for the Colombo District.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TrendScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ============================================================
              // MOH RISK MAP
              // ============================================================
              _FeatureCard(
                icon: Icons.map_rounded,
                title: 'MOH Risk Map',
                description:
                    'View Colombo District MOH-area proxy dengue risk on an interactive map.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiskMapScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ============================================================
              // EXPLAINABLE AI
              // ============================================================
              _FeatureCard(
                icon: Icons.psychology_alt_rounded,
                title: 'Explainable AI',
                description:
                    'Understand dengue risk predictions using Local and Global SHAP explanations.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExplainScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // ============================================================
              // NOTIFICATIONS
              // ============================================================
              _FeatureCard(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                description:
                    'View dengue risk alerts and important warning history from the public-health support system.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF00796B),
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}