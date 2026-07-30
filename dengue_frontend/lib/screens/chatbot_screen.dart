import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_components.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = [];
  bool isLoading = false;

  Future<void> sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"role": "user", "text": text});
      isLoading = true;
    });

    controller.clear();
    final reply = await ApiService.sendMessageAdvanced(text);

    setState(() {
      messages.add({"role": "bot", "data": reply});
      isLoading = false;
    });
  }

  Widget botCard(Map<String, dynamic> data) {
    final List evidence = data["evidence"] ?? [];
    final List locations = data["locations"] ?? [];
    final Map<String, dynamic> mis = Map<String, dynamic>.from(data["misinformation"] ?? {});

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data["response"] ?? "", style: const TextStyle(fontSize: 14.5, height: 1.35, color: kInk)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: Text("Confidence", style: TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
                    Text("${data["confidence"] ?? "N/A"}", style: const TextStyle(color: kGreen, fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (data["confidence"] is num) ? (data["confidence"] as num).toDouble().clamp(0, 1) : 0,
                  color: kGreen,
                  backgroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text("Why this answer", style: TextStyle(fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 4),
          Text(data["why_this_answer"] ?? "", style: const TextStyle(color: kMuted)),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.access_time_rounded, size: 18, color: kPrimary), const SizedBox(width: 6), Expanded(child: Text(data["temporal_insight"] ?? "", style: const TextStyle(color: kMuted)))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.location_on_rounded, size: 18, color: kBlue), const SizedBox(width: 6), Expanded(child: Text(locations.isEmpty ? "Detected Locations: None" : "Detected Locations: ${locations.join(", ")}", style: const TextStyle(color: kMuted)))]),
          const SizedBox(height: 12),
          Chip(
            avatar: Icon(mis["status"] == "Misinformation" ? Icons.warning_rounded : Icons.verified_rounded, size: 18, color: Colors.white),
            label: Text("Misinformation: ${mis["status"] ?? "Unknown"}"),
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            backgroundColor: mis["status"] == "Misinformation" ? kRed : kGreen,
          ),
          const SizedBox(height: 10),
          const Text("Evidence", style: TextStyle(fontWeight: FontWeight.w900, color: kInk)),
          const SizedBox(height: 6),
          ...evidence.map((x) => Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF6F2FF), borderRadius: BorderRadius.circular(14)),
                child: Text("${x["source"]}: ${x["evidence"]}", style: const TextStyle(fontSize: 12.5, color: kMuted)),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("AI Chatbot"), SizedBox(height: 2), Text("Your dengue assistant", style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))])),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: messages.length + (isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (isLoading && index == messages.length) {
                return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
              }

              final msg = messages[index];
              final isUser = msg["role"] == "user";

              if (isUser) {
                return Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [kPrimary, kPrimaryDark]), borderRadius: BorderRadius.circular(20)),
                    child: Text(msg["text"] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                );
              }

              return Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 540), child: botCard(Map<String, dynamic>.from(msg["data"]))));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE7DFF4))),
                  child: TextField(controller: controller, decoration: const InputDecoration(hintText: "Ask anything about dengue...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)), onSubmitted: (_) => sendMessage()),
                ),
              ),
              const SizedBox(width: 10),
              Container(decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kPrimary, kPrimaryDark])), child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white), onPressed: sendMessage)),
            ],
          ),
        ),
      ],
    );
  }
}
