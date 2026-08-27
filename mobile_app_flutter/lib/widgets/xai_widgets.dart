import 'package:flutter/material.dart';

Color riskColor(String risk) => risk == 'High' ? const Color(0xFFE53935) : risk == 'Medium' ? const Color(0xFFFB8C00) : const Color(0xFF43A047);

class AppHeader extends StatelessWidget {
  final String title, subtitle;
  final bool back;
  const AppHeader({super.key, required this.title, this.subtitle = 'Colombo District', this.back = false});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    child: Row(children: [
      if (back) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
      Container(width: 34, height: 34, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF0B5FA5), Color(0xFFFF4B4B)])), child: const Icon(Icons.monitor_heart, color: Colors.white, size: 19)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))])),
      const Icon(Icons.notifications, size: 20)
    ]),
  );
}

class SoftCard extends StatelessWidget {
  final Widget child; final Color? color; final EdgeInsetsGeometry padding;
  const SoftCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(16)});
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 14), padding: padding, decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]), child: child);
}

class MetricTile extends StatelessWidget { final String title, value; final IconData icon; const MetricTile({super.key, required this.title, required this.value, required this.icon});
  @override Widget build(BuildContext context) => Expanded(child: SoftCard(child: Row(children: [Icon(icon, color: const Color(0xFF0B5FA5)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]))])));
}

class XaiBar extends StatelessWidget { final String label; final double value; final String? note; const XaiBar({super.key, required this.label, required this.value, this.note});
  @override Widget build(BuildContext context) { final w = value.clamp(0, 1).toDouble(); return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))), Text('${(w*100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: w, minHeight: 11, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation(Color(0xFF82B9F7)))), if(note!=null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(note!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600))) ])); }
}
