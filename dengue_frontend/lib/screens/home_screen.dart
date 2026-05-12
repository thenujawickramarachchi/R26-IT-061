import 'package:flutter/material.dart';
import '../widgets/app_components.dart';
import 'chatbot_screen.dart';
import 'report_upload_screen.dart';
import 'misinformation_screen.dart';
import 'simulator_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;

  final screens = const [
    DashboardScreen(),
    ChatbotScreen(),
    ReportUploadScreen(),
    MisinformationScreen(),
    SimulatorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: screens[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        height: 72,
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: kPrimary.withOpacity(0.12),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "Home"),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: "Chatbot"),
          NavigationDestination(icon: Icon(Icons.upload_file_outlined), selectedIcon: Icon(Icons.upload_file), label: "Report"),
          NavigationDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: "Verify"),
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), selectedIcon: Icon(Icons.auto_graph), label: "Simulator"),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _goTo(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    state?.setState(() => state.selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kPrimary, kBlue]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.health_and_safety, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Dengue AI",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kInk),
                ),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Welcome back 👋", style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 4),
          const Text("Your AI companion for dengue intelligence.", style: TextStyle(color: kMuted)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary.withOpacity(0.16), kBlue.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: kPrimary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  height: 68,
                  width: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.shield_rounded, color: kPrimary, size: 38),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Current Community Risk", style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text("Moderate", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kPrimaryDark)),
                      SizedBox(height: 4),
                      Text("Stay alert and take precautions.", style: TextStyle(color: kMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 76,
                  width: 76,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 0.58,
                        strokeWidth: 8,
                        backgroundColor: Colors.white,
                        color: kPrimary,
                      ),
                      const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("58", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: kInk)),
                          Text("/100", style: TextStyle(fontSize: 11, color: kMuted)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              MetricTile(icon: Icons.groups_rounded, label: "Cases", value: "1,248", caption: "+12% this week", color: kPrimary),
              SizedBox(width: 10),
              MetricTile(icon: Icons.trending_up_rounded, label: "Trend", value: "Rising", caption: "+18% change", color: kBlue),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              MetricTile(icon: Icons.location_on_rounded, label: "Hotspots", value: "6", caption: "High risk areas", color: kOrange),
              SizedBox(width: 10),
              MetricTile(icon: Icons.check_circle_rounded, label: "Prevention", value: "Follow", caption: "Best practices", color: kGreen),
            ],
          ),
          const SectionTitle("What would you like to do?"),
          _FeatureTile(icon: Icons.smart_toy_rounded, color: kPrimary, title: "AI Chatbot", subtitle: "Ask anything about dengue", onTap: () => _goTo(context, 1)),
          const SizedBox(height: 12),
          _FeatureTile(icon: Icons.description_rounded, color: kBlue, title: "Report Analysis", subtitle: "Upload reports for NLP insights", onTap: () => _goTo(context, 2)),
          const SizedBox(height: 12),
          _FeatureTile(icon: Icons.verified_user_rounded, color: kGreen, title: "Misinformation Detection", subtitle: "Check claims and stay informed", onTap: () => _goTo(context, 3)),
          const SizedBox(height: 12),
          _FeatureTile(icon: Icons.auto_graph_rounded, color: kOrange, title: "Risk Simulator", subtitle: "Test what-if weather scenarios", onTap: () => _goTo(context, 4)),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kInk)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kMuted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kMuted),
        ],
      ),
    );
  }
}
