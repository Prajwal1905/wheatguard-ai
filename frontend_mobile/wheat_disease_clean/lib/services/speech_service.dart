import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final stt.SpeechToText _speech = stt.SpeechToText();

  static Future<String> listenOnce({String locale = "en-IN"}) async {
    bool available = await _speech.initialize();
    if (!available) return "";

    String resultText = "";

    await _speech.listen(
      localeId: locale,
      onResult: (val) {
        resultText = val.recognizedWords;
      },
    );

    await Future.delayed(const Duration(seconds: 3));

    await _speech.stop();

    return resultText;
  }
}
