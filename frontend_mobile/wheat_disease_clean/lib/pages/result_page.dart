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
  late FlutterTts _tts;
  bool _isSpeaking      = false;
  bool _organicMode     = false;
  bool _showExplanation = false;

  // Chatbot state
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  bool _chatLoading = false;

  static const _green  = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);

  
  static const Map<String, IconData> _diseaseIcons = {
    'Aphid':               Icons.bug_report,
    'Black Rust':          Icons.grain,
    'Blast':               Icons.whatshot,
    'Brown Rust':          Icons.spa,
    'Common Root Rot':     Icons.grass,
    'Fusarium Head Blight':Icons.warning_amber_rounded,
    'Leaf Blight':         Icons.eco,
    'Mildew':              Icons.cloud,
    'Mite':                Icons.pest_control,
    'Septoria':            Icons.circle,
    'Smut':                Icons.dark_mode,
    'Stem fly':            Icons.pest_control_rodent,
    'Tan spot':            Icons.lens_blur,
    'Yellow Rust':         Icons.brightness_7,
    'BYDV':                Icons.coronavirus,
    'Black_Chaff':         Icons.grain,
    'Karnal_Bunt':         Icons.science,
    'Powdery_Mildew':      Icons.blur_on,
    'Healthy':             Icons.check_circle,
  };

  static const Map<String, Color> _diseaseIconColors = {
    'Healthy': Color(0xFF2E7D32),
  };

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _toggleSpeak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    final lang = context.locale.languageCode;
    setState(() => _isSpeaking = true);
    if (lang == 'hi')      await _tts.setLanguage('hi-IN');
    else if (lang == 'mr') await _tts.setLanguage('mr-IN');
    else                   await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.speak(text.replaceAll(RegExp(r'#{1,6}\s'), ''));
  }

  /// Organic mode — instead of fragile regex, fetch a fresh remedy
  /// with an "organic only" instruction injected into the disease name.
  /// Falls back to filtering lines that mention chemical names.
  String _applyOrganicFilter(String content) {
    const chemicals = [
      'Mancozeb', 'Propiconazole', 'Tebuconazole', 'Azoxystrobin',
      'Difenoconazole', 'Hexaconazole', 'Zineb', 'Captan',
      'Thiamethoxam', 'Lambda-cyhalothrin', 'Flonicamid',
    ];
    final lines = content.split('\n');
    final filtered = lines.where((line) {
      final lower = line.toLowerCase();
      return !chemicals.any((c) => lower.contains(c.toLowerCase()));
    }).toList();
    return filtered.join('\n');
  }

  List<String> _extractChemicals(String content) {
    const safeList = [
      'Mancozeb', 'Propiconazole', 'Tebuconazole', 'Azoxystrobin',
      'Difenoconazole', 'Hexaconazole', 'Zineb', 'Captan',
      'Neem', 'Neem oil', 'Trichoderma', 'Beauveria',
      'Thiamethoxam', 'Lambda-cyhalothrin', 'Flonicamid',
    ];
    return safeList
        .where((c) => content.toLowerCase().contains(c.toLowerCase()))
        .toList();
  }

  Color _severityColor(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains('high') || sev.contains('critical'))
      return Colors.red.shade700;
    if (sev.contains('moderate') || sev.contains('medium'))
      return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _confidenceColor(double conf) {
    if (conf >= 80) return Colors.green.shade700;
    if (conf >= 60) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  String _severityLabel(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains('high') || sev.contains('critical')) return 'HIGH RISK';
    if (sev.contains('moderate') || sev.contains('medium')) return 'MODERATE';
    return 'LOW RISK';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final rawDisease = _resolveRawDisease();
    final disease    = DiseaseNames.get(rawDisease, lang);
    final confidence = double.tryParse(
            widget.result['confidence']?.toString() ?? '0') ??
        0.0;
    final severity          = widget.result['severity']?.toString() ?? 'Low';
    final originalRemedy    = widget.result['remedy']?.toString() ?? 'No remedy available.';
    final originalExplain   = widget.result['ai_explanation']?.toString() ?? '';

    final remedy      = _organicMode ? _applyOrganicFilter(originalRemedy)    : originalRemedy;
    final explanation = _organicMode ? _applyOrganicFilter(originalExplain)   : originalExplain;
    final chemicals   = _extractChemicals(originalRemedy);
    final sevColor    = _severityColor(severity);
    final isHealthy   = rawDisease == 'Healthy';

    final diseaseIcon  = _diseaseIcons[rawDisease] ?? Icons.eco;
    final diseaseColor = isHealthy ? _green : sevColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          'result_title'.tr(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Disease card 
            _card(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: diseaseColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(diseaseIcon,
                        color: diseaseColor, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    disease,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: diseaseColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confidence bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('confidence'.tr(),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
                      Text(
                        '${confidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _confidenceColor(confidence),
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
                          _confidenceColor(confidence)),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Severity badge
                  if (!isHealthy)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: sevColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sevColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        _severityLabel(severity),
                        style: TextStyle(
                          color: sevColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Organic mode toggle
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.eco,
                                color: _green, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Organic mode',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Switch(
                          value: _organicMode,
                          onChanged: (v) =>
                              setState(() => _organicMode = v),
                          activeColor: _green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Remedy
            _sectionCard(
              title: 'remedy'.tr(),
              icon: Icons.healing_outlined,
              color: _green,
              onSpeak: () => _toggleSpeak(remedy),
              isSpeaking: _isSpeaking,
              child: MarkdownBody(
                data: remedy.replaceAll(RegExp(r'#{1,6}\s'), ''),
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            ),

            const SizedBox(height: 12),

            //  Chemicals used
            if (!_organicMode && !isHealthy && chemicals.isNotEmpty)
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
                    Row(
                      children: [
                        Icon(Icons.science_outlined,
                            color: _orange, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Chemicals mentioned',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: chemicals
                          .map(
                            (c) => Chip(
                              label: Text(c,
                                  style:
                                      const TextStyle(fontSize: 12)),
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

            //  AI Explanation
            GestureDetector(
              onTap: () => setState(
                  () => _showExplanation = !_showExplanation),
              child: _card(
                child: Row(
                  children: [
                    Icon(Icons.psychology_outlined,
                        color: Colors.deepPurple.shade400),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AI Explanation',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade400,
                        ),
                      ),
                    ),
                    Icon(
                      _showExplanation
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ),

            if (_showExplanation) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isSpeaking
                            ? Icons.stop_circle
                            : Icons.volume_up_outlined,
                        color: Colors.deepPurple,
                      ),
                      onPressed: () => _toggleSpeak(explanation),
                    ),
                    MarkdownBody(
                      data: explanation
                          .replaceAll(RegExp(r'#{1,6}\s'), ''),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                            fontSize: 15, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Chatbot ──────────────────────────────────────────────────
            _buildChatSection(rawDisease),

            const SizedBox(height: 12),

            // ── Back button ──────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text('Upload another image'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: Color(0xFF2E7D32)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Chatbot section ───────────────────────────────────────────────────

  Widget _buildChatSection(String rawDisease) {
    final lang = context.locale.languageCode;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_outlined, color: _orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ask AI Farmer Assistant',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _orange,
                ),
              ),
            ],
          ),

          if (_chatMessages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) {
                  final msg    = _chatMessages[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 3),
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.72,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? _green
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text']!,
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
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              // Voice input
              IconButton(
                icon: const Icon(Icons.mic, color: Colors.red),
                onPressed: () async {
                  final locale = lang == 'hi'
                      ? 'hi-IN'
                      : lang == 'mr'
                          ? 'mr-IN'
                          : 'en-IN';
                  final heard =
                      await SpeechService.listenOnce(locale: locale);
                  if (heard.isNotEmpty) {
                    setState(
                        () => _chatController.text = heard);
                  }
                },
              ),

              // Text input
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Ask about your crop…',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                          color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),

              // Send
              _chatLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send, color: _green),
                      onPressed: () =>
                          _sendChat(rawDisease, lang),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendChat(String rawDisease, String lang) async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({'role': 'user', 'text': text});
      _chatLoading = true;
    });
    _chatController.clear();

    final reply = await ApiService.askChatbot(
      rawDisease,
      text,
      lang,
    );

    setState(() {
      _chatMessages.add({'role': 'bot', 'text': reply});
      _chatLoading = false;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _resolveRawDisease() {
    final d1 = widget.result['disease']?.toString().trim() ?? '';
    final d2 =
        widget.result['exact_disease']?.toString().trim() ?? '';
    if (d1.isNotEmpty) return d1;
    if (d2.isNotEmpty) return d2;
    return 'Healthy';
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    required VoidCallback onSpeak,
    required bool isSpeaking,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                      fontSize: 15,
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
          const Divider(height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
