import 'package:flutter/material.dart';

import 'screens/dengue_prediction_screen.dart';

void main() {
  runApp(const DenguePredictionApp());
}

class DenguePredictionApp extends StatelessWidget {
  const DenguePredictionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vector Shield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F8),
      ),
      home: const DenguePredictionScreen(),
    );
  }
}