import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dashboardHeader(),
              const SizedBox(height: 18),
              _statusOverview(),
              const SizedBox(height: 22),
              _sectionTitle(
                titleText: 'Research Summary',
                subtitleText: 'Current component information',
              ),
              const SizedBox(height: 14),
              _researchSummaryCard(),
              const SizedBox(height: 22),
              _sectionTitle(
                titleText: 'Prototype Progress',
                subtitleText: 'Current 50% to 60% progress status',
              ),
              const SizedBox(height: 14),
              _progressCard(),
              const SizedBox(height: 22),
              _sectionTitle(
                titleText: 'System Flow',
                subtitleText: 'How the mobile app connects with AI backend',
              ),
              const SizedBox(height: 14),
              _flowCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardHeader() {
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
            right: -15,
            top: -15,
            child: Icon(
              Icons.coronavirus_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dengue RL Agent\nDashboard',
                style: TextStyle(
                  fontSize: 28,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Overview of AI method, dataset, backend connection, and prototype progress.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusOverview() {
    return Row(
      children: [
        Expanded(
          child: _statusCard(
            value: '708',
            label: 'Weeks Data',
            icon: Icons.dataset_rounded,
            color: Colors.lightBlue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statusCard(
            value: '3000',
            label: 'Episodes',
            icon: Icons.auto_graph_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statusCard(
            value: '12',
            label: 'MOH Areas',
            icon: Icons.location_city_rounded,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: title,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: sub),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String titleText,
    required String subtitleText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleText,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: title,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitleText, style: const TextStyle(color: sub, fontSize: 13)),
      ],
    );
  }

  Widget _researchSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _summaryRow(
            icon: Icons.memory_rounded,
            titleText: 'AI Method',
            value: 'Q-Learning RL',
            color: Colors.purple,
          ),
          const Divider(color: border, height: 24),
          _summaryRow(
            icon: Icons.mobile_friendly_rounded,
            titleText: 'Frontend',
            value: 'Flutter App',
            color: Colors.lightBlue,
          ),
          const Divider(color: border, height: 24),
          _summaryRow(
            icon: Icons.api_rounded,
            titleText: 'Backend',
            value: 'Python Flask API',
            color: Colors.green,
          ),
          const Divider(color: border, height: 24),
          _summaryRow(
            icon: Icons.email_rounded,
            titleText: 'Special Feature',
            value: 'PHI Email Alert',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String titleText,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            titleText,
            style: const TextStyle(color: sub, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: title,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _progressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.task_alt_rounded, color: Colors.green, size: 26),
              SizedBox(width: 10),
              Text(
                'Working Prototype',
                style: TextStyle(
                  color: title,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.60,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Current progress: 60% prototype demo ready',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          _bulletText('RL model connected with backend'),
          _bulletText('Mobile app connected through API'),
          _bulletText('Recommendation and HIGH risk alert working'),
          _bulletText(
            'Next phase: database, automation, area-wise PHI mapping',
          ),
        ],
      ),
    );
  }

  Widget _flowCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _flowItem('1', 'User enters dengue situation data'),
          _flowArrow(),
          _flowItem('2', 'Flutter app sends data to Flask backend'),
          _flowArrow(),
          _flowItem('3', 'Q-Learning model recommends best intervention'),
          _flowArrow(),
          _flowItem('4', 'HIGH risk triggers PHI warning email'),
        ],
      ),
    );
  }

  Widget _flowItem(String number, String text) {
    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: red.withValues(alpha: 0.12),
          child: Text(
            number,
            style: const TextStyle(color: red, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(color: sub, height: 1.4)),
        ),
      ],
    );
  }

  Widget _flowArrow() {
    return const Padding(
      padding: EdgeInsets.only(left: 14, top: 6, bottom: 6),
      child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9CA3AF)),
    );
  }

  Widget _bulletText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: sub, fontSize: 15)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: sub, height: 1.35, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
