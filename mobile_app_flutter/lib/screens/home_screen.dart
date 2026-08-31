import 'package:flutter/material.dart';

import '../services/backend_config.dart';
import 'dengue_prediction_screen.dart';
import 'trend_screen.dart';
import 'risk_map_screen.dart';
import 'rl_dashboard_screen.dart';
import 'recommendation_screen.dart';
import 'phi_warning_screen.dart';
import 'warning_history_screen.dart';
import 'intervention_feedback_screen.dart';
import 'explain_screen.dart';
import 'inspection_screen.dart';
import 'nlp_screen.dart';
import 'settings_screen.dart';
import 'manual_prediction_screen.dart';
import 'historical_prediction_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const Color primary = Color(0xFF00796B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dengue Health SL",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    baseUrl: BackendConfig.baseUrl,
                    apiKey: BackendConfig.apiKey,
                    onConnectionSaved: (String baseUrl, String apiKey) async {
                      await BackendConfig.save(baseUrl, apiKey);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Text(
                "AI-Based Dengue Public Health\nSupport System",

                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                "Monitor dengue risk, predictions and public health actions.",

                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),

              const SizedBox(height: 20),

              _RiskCard(),

              const SizedBox(height: 24),

              const Text(
                "Quick Access",

                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 0.85,

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                crossAxisSpacing: 12,

                mainAxisSpacing: 12,

                children: [
                  _QuickCard(
                    icon: Icons.analytics,

                    title: "Future Prediction",

                    page: const DenguePredictionScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.analytics_outlined,
                    title: "Historical Prediction",
                    page: HistoricalPredictionScreen(),
                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.edit_note,
                    title: "Manual Prediction",
                    page: const ManualPredictionScreen(),
                    context: context,
                  ),

                  

                  _QuickCard(
                    icon: Icons.map,

                    title: "MOH Risk Map",

                    page: const RiskMapScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.warning,

                    title: "PHI Warning",

                    page: const PHIWarningScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.auto_awesome,

                    title: "RL Recommendation",

                    page: const RecommendationScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.show_chart,

                    title: "Trends",

                    page: const TrendScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.dashboard,

                    title: "Dashboard",

                    page: const RLDashboardScreen(),

                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.psychology_outlined,
                    title: "Dengue NLP",
                    page: NlpScreen(
                      baseUrl: BackendConfig.baseUrl,
                      apiKey: BackendConfig.apiKey,
                    ),
                    context: context,
                  ),

                  _QuickCard(
                    icon: Icons.assignment_turned_in_outlined,
                    title: "PHI Inspection",
                    page: InspectionScreen(
                      baseUrl: BackendConfig.baseUrl,
                      apiKey: BackendConfig.apiKey,
                    ),
                    context: context,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _SafetyCard(),

              const SizedBox(height: 20),

              _MoreSection(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: const Color(0xFF00695C),

        borderRadius: BorderRadius.circular(22),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Text(
            "Current District Risk",

            style: TextStyle(color: Colors.white, fontSize: 15),
          ),

          const SizedBox(height: 8),

          const Text(
            "MEDIUM",

            style: TextStyle(
              color: Colors.orange,

              fontSize: 32,

              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Colombo District\nWeek 35, 2026",

            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  static const Color primary = Color(0xFF00796B);

  final IconData icon;

  final String title;

  final Widget page;

  final BuildContext context;

  const _QuickCard({
    required this.icon,

    required this.title,

    required this.page,

    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),

      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },

      child: Container(
        padding: const EdgeInsets.all(8),

        decoration: BoxDecoration(
          color: const Color(0xFFF1F8F7),

          borderRadius: BorderRadius.circular(18),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              padding: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),

                borderRadius: BorderRadius.circular(14),
              ),

              child: Icon(icon, color: primary),
            ),

            const SizedBox(height: 8),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F2),

        borderRadius: BorderRadius.circular(18),
      ),

      child: const Row(
        children: [
          Icon(Icons.health_and_safety, color: Color(0xFF00796B)),

          SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  "Stay informed, Stay safe",

                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                Text(
                  "Use AI and ML to protect our community from dengue outbreaks.",

                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _MoreSection(BuildContext context) {
  return Column(
    children: [
      _MoreTile(
        context,

        "Warning History",

        Icons.history,

        const WarningHistoryScreen(),
      ),

      _MoreTile(
        context,

        "Intervention Feedback",

        Icons.feedback,

        const InterventionFeedbackScreen(),
      ),

      _MoreTile(
        context,

        "Explainable AI",

        Icons.psychology,

        const ExplainScreen(),
      ),
    ],
  );
}

Widget _MoreTile(
  BuildContext context,

  String title,

  IconData icon,

  Widget page,
) {
  return Card(
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF00796B)),

      title: Text(title),

      trailing: const Icon(Icons.arrow_forward_ios, size: 16),

      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    ),
  );
}
