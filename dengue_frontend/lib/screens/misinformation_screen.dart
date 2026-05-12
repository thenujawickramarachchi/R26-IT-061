import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_components.dart';

class MisinformationScreen extends StatefulWidget {
  const MisinformationScreen({super.key});

  @override
  State<MisinformationScreen> createState() => _MisinformationScreenState();
}

class _MisinformationScreenState extends State<MisinformationScreen> {
  final TextEditingController controller = TextEditingController();
  Map<String, dynamic>? result;
  bool isLoading = false;

  Future<void> checkClaim() async {
    final claim = controller.text.trim();
    if (claim.isEmpty) return;

    setState(() {
      isLoading = true;
      result = null;
    });

    final response = await ApiService.checkMisinformation(claim);

    setState(() {
      result = response;
      isLoading = false;
    });
  }

  Color getStatusColor(String status) {
    if (status == "Misinformation") return kRed;
    if (status == "Unverified") return kOrange;
    if (status == "Error") return kMuted;
    return kGreen;
  }

  @override
  Widget build(BuildContext context) {
    final status = result?["status"] ?? "";
    final color = getStatusColor(status);

    return Column(
      children: [
        AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Misinformation Detection"), SizedBox(height: 2), Text("Verify claims and stay informed", style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))])),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle("Enter Claim"),
              TextField(
                controller: controller,
                maxLines: 5,
                maxLength: 300,
                decoration: InputDecoration(
                  hintText: "Example: Papaya leaf can cure dengue instantly",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE7DFF4))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE7DFF4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              GradientButton(text: "Check Claim", icon: Icons.fact_check_rounded, onPressed: checkClaim),
              const SizedBox(height: 22),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              if (result != null) ...[
                const SectionTitle("Result"),
                SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(height: 58, width: 58, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)), child: Icon(status == "Misinformation" ? Icons.gpp_bad_rounded : Icons.verified_user_rounded, color: color, size: 34)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(status, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color)), const SizedBox(height: 4), Text("Confidence: ${result?["confidence"]}", style: const TextStyle(color: kMuted))])),
                  ]),
                  const SizedBox(height: 18),
                  const Text("Explanation", style: TextStyle(fontWeight: FontWeight.w900, color: kInk)),
                  const SizedBox(height: 6),
                  Text(result?["explanation"] ?? "", style: const TextStyle(color: kMuted)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: kGreen.withOpacity(0.20))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_rounded, color: kGreen), const SizedBox(width: 10), Expanded(child: Text(result?["recommendation"] ?? "", style: const TextStyle(color: kInk, height: 1.35)))]),
                  ),
                ])),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
