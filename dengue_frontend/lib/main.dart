import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DengueAIApp());
}

class DengueAIApp extends StatelessWidget {
  const DengueAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF8FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6D35F4),
          primary: const Color(0xFF6D35F4),
          secondary: const Color(0xFF2F80ED),
          tertiary: const Color(0xFF00A86B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8FF),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF17142A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          iconTheme: IconThemeData(color: Color(0xFF17142A)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
