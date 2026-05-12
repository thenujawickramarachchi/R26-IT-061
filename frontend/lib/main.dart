import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() => runApp(const DengueApp());

class DengueApp extends StatelessWidget {
  const DengueApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dengue Analytics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5FA5), primary: const Color(0xFF0B5FA5), secondary: const Color(0xFFFF4B4B)),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        cardTheme: CardThemeData(elevation: 2, shadowColor: Colors.black12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      ),
      home: const SplashScreen(),
    );
  }
}
