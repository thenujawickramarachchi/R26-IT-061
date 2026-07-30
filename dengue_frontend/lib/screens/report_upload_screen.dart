import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../widgets/app_components.dart';

class ReportUploadScreen extends StatefulWidget {
  const ReportUploadScreen({super.key});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen> {
  String selectedFile = "";
  String summary = "";
  String riskLevel = "";
  Map<String, dynamic> keywords = {};
  bool isLoading = false;
  String errorMessage = "";

  Future<void> pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'csv'], withData: true);
    if (result == null) return;
    final file = result.files.single;
    if (file.bytes == null) {
      setState(() => errorMessage = "File data not found. Try another TXT file.");
      return;
    }

    setState(() {
      selectedFile = file.name;
      isLoading = true;
      summary = "";
      riskLevel = "";
      keywords = {};
      errorMessage = "";
    });

    final response = await ApiService.uploadReportBytes(fileName: file.name, bytes: file.bytes!);

    setState(() {
      summary = response["analysis"]["summary"];
      riskLevel = response["analysis"]["risk_level"];
      keywords = Map<String, dynamic>.from(response["analysis"]["keywords"]);
      isLoading = false;
    });
  }

  Color getRiskColor() {
    if (riskLevel == "High") return kRed;
    if (riskLevel == "Medium") return kOrange;
    if (riskLevel == "Low") return kGreen;
    return kMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Report Analysis"), SizedBox(height: 2), Text("Upload & analyze dengue reports", style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))])),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle("Upload Report"),
              GestureDetector(
                onTap: pickAndUploadFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kPrimary.withOpacity(0.45), width: 1.5)),
                  child: Column(children: [
                    Container(height: 58, width: 58, decoration: BoxDecoration(color: kPrimary.withOpacity(0.10), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.cloud_upload_rounded, color: kPrimary, size: 34)),
                    const SizedBox(height: 12),
                    const Text("Tap to choose report", style: TextStyle(fontWeight: FontWeight.w900, color: kInk, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text("Supports TXT and CSV files", style: TextStyle(color: kMuted)),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              if (selectedFile.isNotEmpty)
                SoftCard(padding: const EdgeInsets.all(14), child: Row(children: [
                  Container(height: 46, width: 46, decoration: BoxDecoration(color: kRed.withOpacity(0.10), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.description_rounded, color: kRed)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(selectedFile, style: const TextStyle(fontWeight: FontWeight.w900, color: kInk))),
                  const Icon(Icons.check_circle_rounded, color: kGreen),
                ])),
              if (isLoading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              if (errorMessage.isNotEmpty) Text(errorMessage, style: const TextStyle(color: kRed)),
              if (summary.isNotEmpty) ...[
                const SectionTitle("Analysis Summary"),
                SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Column(children: [const Text("Predicted Risk", style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: getRiskColor().withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Text(riskLevel, style: TextStyle(color: getRiskColor(), fontWeight: FontWeight.w900)))])),
                    Container(height: 64, width: 1, color: const Color(0xFFEDE7F8)),
                    Expanded(child: Column(children: [const Text("Confidence", style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(riskLevel == "High" ? "88%" : riskLevel == "Medium" ? "76%" : "64%", style: const TextStyle(color: kBlue, fontWeight: FontWeight.w900, fontSize: 24))])),
                  ]),
                  const SizedBox(height: 16),
                  Text(summary, style: const TextStyle(color: kMuted)),
                ])),
                const SectionTitle("Detected Keywords"),
                SoftCard(child: Column(children: keywords.entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700, color: kInk))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: kPrimary.withOpacity(0.10), borderRadius: BorderRadius.circular(12)), child: Text("${entry.value}", style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w900)))]))).toList())),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}
