import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/api_service.dart';
import '../services/speech_service.dart';
import '../utils/disease_names.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic> result;
  const ResultPage({super.key, required this.result});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late FlutterTts tts;
  bool isSpeaking = false;
  bool organicMode = false;
  bool showExplanation = false;

  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();
    tts.setCompletionHandler(() => setState(() => isSpeaking = false));
  }

  Future<void> toggleSpeak(String text) async {
    if (isSpeaking) {
      await tts.stop();
      setState(() => isSpeaking = false);
      return;
    }
    final lang = context.locale.languageCode;
    setState(() => isSpeaking = true);
    if (lang == "hi") await tts.setLanguage("hi-IN");
    else if (lang == "mr") await tts.setLanguage("mr-IN");
    else await tts.setLanguage("en-US");
    await tts.setSpeechRate(0.45);
    await tts.speak(text.replaceAll("###", ""));
  }

  List<String> extractChemicals(String content) {
    final safeList = [
      "Mancozeb", "Propiconazole", "Tebuconazole", "Azoxystrobin",
      "Difenoconazole", "Hexaconazole", "Zineb", "Captan",
      "Neem", "Neem oil", "Trichoderma", "Beauveria",
    ];
    final found = safeList
        .where((c) => content.toLowerCase().contains(c.toLowerCase()))
        .toList();
    return found.isEmpty ? ["No chemicals used"] : found;
  }

  Color severityColor(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains("high")) return Colors.red.shade700;
    if (sev.contains("moderate") || sev.contains("medium"))
      return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  String severityLabel(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains("high")) return "HIGH RISK";
    if (sev.contains("moderate") || sev.contains("medium")) return "MODERATE";
    return "LOW RISK";
  }

  String diseaseIcon(String disease) {
    final map = {
      "Aphid": "🪲",
      "Mite": "🕷️",
      "Stem fly": "🪰",
      "Leaf Blight": "🍁",
      "Tan spot": "🍂",
      "Mildew": "🌫️",
      "Common Root Rot": "🌱",
      "Fusarium Head Blight": "⚠️",
      "Black Rust": "🌾",
      "Brown Rust": "🌾",
      "Yellow Rust": "🌾",
      "Smut": "🌿",
      "Blast": "🔥",
      "Septoria": "🟤",
      "Healthy": "✔️",
    };
    return map[disease] ?? "🌾";
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    String rawDisease = "";
    if (widget.result['disease'] != null &&
        widget.result['disease'] != "") {
      rawDisease = widget.result['disease'].toString().trim();
    } else if (widget.result['exact_disease'] != null &&
        widget.result['exact_disease'] != "") {
      rawDisease = widget.result['exact_disease'].toString().trim();
    } else {
      rawDisease = "Healthy";
    }

    final disease = DiseaseNames.get(rawDisease, lang);
    final confidenceRaw = widget.result['confidence'] ?? 0;
    final confidence =
        double.tryParse(confidenceRaw.toString()) ?? 0.0;
    final severity = widget.result['severity']?.toString() ?? "Low";
    final originalRemedy =
        widget.result['remedy']?.toString() ?? "No remedy available.";
    final originalExplanation =
        widget.result['ai_explanation']?.toString() ??
            "No explanation available.";

    String remedy = organicMode
        ? originalRemedy.replaceAll(
            RegExp(r'- .*?(Mancozeb|azole|Zineb|Captan).*'), "")
        : originalRemedy;
    String explanation = organicMode
        ? originalExplanation.replaceAll(
            RegExp(r'- .*?(Mancozeb|azole|Zineb|Captan).*'), "")
        : originalExplanation;

    final chemicals = extractChemicals(originalRemedy);
    final sevColor = severityColor(severity);
    final isHealthy = rawDisease == "Healthy";

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          "Disease Result".tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Disease Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    diseaseIcon(rawDisease),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    disease,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isHealthy ? _green : sevColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confidence bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr('confidence'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "${confidence.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: confidence / 100,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            confidence >= 80
                                ? Colors.green
                                : confidence >= 60
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Severity badge
                  if (!isHealthy)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: sevColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        severityLabel(severity),
                        style: TextStyle(
                          color: sevColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Organic Mode toggle
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Organic Mode",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: organicMode,
                          onChanged: (v) =>
                              setState(() => organicMode = v),
                          activeColor: _green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Remedy Card
            _buildSection(
              title: tr("remedy"),
              color: _green,
              icon: Icons.healing_outlined,
              onSpeak: () => toggleSpeak(remedy),
              isSpeaking: isSpeaking,
              child: MarkdownBody(
                data: remedy.replaceAll("###", ""),
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Chemicals
            if (!organicMode && !isHealthy) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Chemicals Mentioned".tr(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: chemicals
                          .map(
                            (c) => Chip(
                              label: Text(
                                c,
                                style: const TextStyle(fontSize: 13),
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                  color: Colors.orange.shade300),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // AI Explanation collapsible
            GestureDetector(
              onTap: () =>
                  setState(() => showExplanation = !showExplanation),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_outlined,
                          color: Colors.deepPurple.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "AI Explanation".tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade400,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      showExplanation
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ),

            if (showExplanation) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(
                            isSpeaking
                                ? Icons.stop_circle
                                : Icons.volume_up_outlined,
                            color: Colors.deepPurple,
                          ),
                          onPressed: () => toggleSpeak(explanation),
                        ),
                      ],
                    ),
                    MarkdownBody(
                      data: explanation.replaceAll("###", ""),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Ask AI Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _openChatbot(context, rawDisease),
                icon: const Icon(Icons.chat_outlined),
                label: Text(
                  "Ask Doubts to AI".tr(),
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Upload Another Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: Text(
                  "Upload Another Image".tr(),
                  style: const TextStyle(fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color color,
    required IconData icon,
    required Widget child,
    required VoidCallback onSpeak,
    required bool isSpeaking,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  isSpeaking
                      ? Icons.stop_circle
                      : Icons.volume_up_outlined,
                  color: color,
                ),
                onPressed: onSpeak,
              ),
            ],
          ),
          const Divider(),
          child,
        ],
      ),
    );
  }

  void _openChatbot(BuildContext context, String rawDisease) {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> msgs = [];
    final lang = context.locale.languageCode;
    final locale =
        lang == "hi" ? "hi-IN" : lang == "mr" ? "mr-IN" : "en-IN";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Farmer Chatbot",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: msgs.isEmpty
                          ? Center(
                              child: Text(
                                "Ask anything about your crop disease",
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: msgs.length,
                              itemBuilder: (_, i) {
                                final m = msgs[i];
                                final isUser = m["role"] == "user";
                                return Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.75,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? const Color(0xFF2E7D32)
                                          : Colors.grey.shade100,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      m["text"]!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.mic, color: Colors.red),
                            onPressed: () async {
                              final heard =
                                  await SpeechService.listenOnce(
                                locale: locale,
                              );
                              if (heard.isNotEmpty) {
                                controller.text = heard;
                                setState(() {});
                              }
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: "Ask your question…".tr(),
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFF2E7D32),
                            ),
                            onPressed: () async {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                msgs.add(
                                    {"role": "user", "text": text});
                              });
                              controller.clear();
                              final reply =
                                  await ApiService.askChatbot(
                                rawDisease,
                                text,
                                lang,
                              );
                              setState(() {
                                msgs.add(
                                    {"role": "bot", "text": reply});
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}