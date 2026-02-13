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
  bool chatbotSpeaking = false;
  bool organicMode = false; 

  @override
  void initState() {
    super.initState();
    tts = FlutterTts();

    tts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
  }

  Future<void> toggleSpeak(String text) async {
    if (isSpeaking) {
      await tts.stop();
      setState(() => isSpeaking = false);
      return;
    }

    final lang = context.locale.languageCode;
    setState(() => isSpeaking = true);

    if (lang == "hi") {
      await tts.setLanguage("hi-IN");
    } else if (lang == "mr") await tts.setLanguage("mr-IN");
    else await tts.setLanguage("en-US");

    await tts.setSpeechRate(0.45);

    
    await tts.speak(text.replaceAll("###", ""));
  }

  List<String> extractChemicals(String content) {
    final List<String> safeList = [
      "Mancozeb",
      "Propiconazole",
      "Tebuconazole",
      "Azoxystrobin",
      "Difenoconazole",
      "Hexaconazole",
      "Zineb",
      "Captan",
      "Neem",
      "Neem oil",
      "Trichoderma",
      "Beauveria",
    ];

    final found = safeList.where((c) =>
        content.toLowerCase().contains(c.toLowerCase())).toList();

    return found.isEmpty ? ["No chemicals used"] : found;
  }

  
  Color severityColor(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains("high")) return Colors.red;
    if (sev.contains("moderate") || sev.contains("medium")) {
      return Colors.orange;
    }
    return Colors.green;
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

    if (widget.result['disease'] != null && widget.result['disease'] != "") {
      rawDisease = widget.result['disease'].toString().trim();
    }
    else if (widget.result['exact_disease'] != null && widget.result['exact_disease'] != "") {
      rawDisease = widget.result['exact_disease'].toString().trim();
    }
    else {
      rawDisease = "Healthy";
    }


    final disease = DiseaseNames.get(rawDisease, lang);

    final confidence = widget.result['confidence']?.toString() ?? "0";
    final severity = widget.result['severity']?.toString() ?? "Low";

    final originalRemedy = widget.result['remedy']?.toString() 
      ?? "- No remedy available right now.";

    final originalExplanation = widget.result['ai_explanation']?.toString() 
      ?? "- No explanation available right now.";

    
    String remedy = organicMode
        ? originalRemedy.replaceAll(RegExp(r'- .*?(Mancozeb|azole|Zineb|Captan).*'), "")
        : originalRemedy;

    String explanation = organicMode
        ? originalExplanation.replaceAll(RegExp(r'- .*?(Mancozeb|azole|Zineb|Captan).*'), "")
        : originalExplanation;

    final chemicals = extractChemicals(originalRemedy);
    final color = severityColor(severity);

    return Scaffold(
      appBar: AppBar(
        title: Text("Disease Result".tr()),
        backgroundColor: Colors.green,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 20),

            
            Text(
              "${diseaseIcon(rawDisease)} $disease",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "${tr('confidence')}: $confidence%",
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 10),

           
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Switch(
                  value: organicMode,
                  onChanged: (v) => setState(() => organicMode = v),
                  activeThumbColor: Colors.green,
                ),
                Text(
                  "Organic Mode".tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(),

            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr("remedy"),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                IconButton(
                  icon: Icon(
                    isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded,
                    color: Colors.green,
                  ),
                  onPressed: () => toggleSpeak(remedy),
                ),
              ],
            ),

            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MarkdownBody(
                  data: remedy.replaceAll("###", ""),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 17, height: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            
            if (!organicMode) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Chemicals Mentioned".tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: chemicals
                    .map((c) => Chip(
                          label: Text(c),
                          backgroundColor: Colors.orange.shade50,
                          labelStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            Divider(),

            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "AI Explanation".tr(),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple),
                ),
                IconButton(
                  icon: Icon(
                    isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () => toggleSpeak(explanation),
                ),
              ],
            ),

            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MarkdownBody(
                  data: explanation.replaceAll("###", ""),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 17, height: 1.5),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () => _openChatbot(context, rawDisease),
              icon: const Icon(Icons.chat),
              label: const Text("Ask Doubts to AI"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Upload Another Image"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  
  void _openChatbot(BuildContext context, String rawDisease) {
    final TextEditingController controller = TextEditingController();
    final List<Map<String, String>> msgs = [];
    final lang = context.locale.languageCode;

    final displayDisease = DiseaseNames.get(rawDisease, lang);

    final locale = (lang == "hi")
        ? "hi-IN"
        : (lang == "mr")
            ? "mr-IN"
            : "en-IN";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "🌾 Farmer Chatbot",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: msgs.length,
                        itemBuilder: (_, i) {
                          final m = msgs[i];
                          final isUser = m["role"] == "user";

                          return Align(
                            alignment:
                                isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    isUser ? Colors.green.shade200 : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                m["text"]!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.mic, color: Colors.red),
                          onPressed: () async {
                            final heard =
                                await SpeechService.listenOnce(locale: locale);
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
                                border: const OutlineInputBorder()),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.green),
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;

                            setState(() {
                              msgs.add({"role": "user", "text": text});
                            });

                            controller.clear();

                            final reply = await ApiService.askChatbot(
                                rawDisease, text, lang);

                            setState(() {
                              msgs.add({"role": "bot", "text": reply});
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),
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
