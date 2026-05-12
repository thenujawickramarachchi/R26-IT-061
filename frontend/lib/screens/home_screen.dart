import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'explain_screen.dart';
import 'trend_screen.dart';
import 'risk_map_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final screens = const [
    DashboardScreen(),
    ExplainScreen(),
    TrendScreen(),
    RiskMapScreen(),
    NotificationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() {
            index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_alt),
            label: "XAI",
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: "Trend",
          ),
          NavigationDestination(
            icon: Icon(Icons.map),
            label: "Map",
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: "Alerts",
          ),
        ],
      ),
    );
  }
}