import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
      appBar: AppBar(title: const Text('About Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 18),
            _infoTile(
              Icons.psychology_alt_rounded,
              'AI Method',
              'Q-Learning Reinforcement Learning',
            ),
            _infoTile(
              Icons.dataset_rounded,
              'Dataset',
              '708 weeks of dengue data',
            ),
            _infoTile(
              Icons.repeat_rounded,
              'Training Episodes',
              '3,000 episodes',
            ),
            _infoTile(
              Icons.location_city_rounded,
              'Coverage',
              '12 Colombo District MOH areas',
            ),
            _infoTile(
              Icons.health_and_safety_rounded,
              'Purpose',
              'Recommend best dengue intervention action',
            ),
            _infoTile(Icons.school_rounded, 'University', 'SLIIT'),
            const SizedBox(height: 14),
            _textCard(
              titleText: 'Research Explanation',
              body:
                  'This mobile application connects to a Python backend API. '
                  'The backend loads the trained Q-Learning model and recommends '
                  'the best dengue intervention action based on MOH area, cases, '
                  'rainfall and temperature. If a HIGH risk situation is detected, '
                  'the system can send a warning email to the PHI officer.',
            ),
            const SizedBox(height: 14),
            _statusCard(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFE53935)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dengue Intervention Optimization Agent',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'AI-powered decision support system for Sri Lanka MOH dengue intervention planning.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String tileTitle, String value) {
    return Card(
      color: card,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: red.withValues(alpha: 0.12),
          child: Icon(icon, color: red),
        ),
        title: Text(
          tileTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, color: title),
        ),
        subtitle: Text(value, style: const TextStyle(color: sub)),
      ),
    );
  }

  Widget _textCard({required String titleText, required String body}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: title,
            ),
          ),
          const SizedBox(height: 10),
          Text(body, style: const TextStyle(height: 1.5, color: sub)),
        ],
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Prototype Status',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: title,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Completed Features',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          SizedBox(height: 6),
          Text(
            '• Flutter mobile application\n'
            '• Python Flask backend API\n'
            '• Trained Q-Learning model integration\n'
            '• Dengue risk level display\n'
            '• Intervention recommendation\n'
            '• PHI warning email for HIGH risk',
            style: TextStyle(height: 1.5, color: sub),
          ),
          SizedBox(height: 14),
          Text(
            'Next Phase Improvements',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          SizedBox(height: 6),
          Text(
            '• Area-wise PHI email mapping\n'
            '• Database integration\n'
            '• Automated weekly dengue data loading\n'
            '• Recommendation history\n'
            '• Dashboard and reporting',
            style: TextStyle(height: 1.5, color: sub),
          ),
        ],
      ),
    );
  }
}
