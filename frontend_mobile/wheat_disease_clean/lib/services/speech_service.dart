import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static final stt.SpeechToText _speech = stt.SpeechToText();

  /// Listens for speech and returns recognized text.
  /// Returns empty string if permission denied, mic unavailable,
  /// or nothing was heard.
  static Future<String> listenOnce({String locale = "en-IN"}) async {
    // 1. Check / request microphone permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        return ""; // permission denied
      }
    }

    // 2. Initialize speech recognition
    bool available = await _speech.initialize(
      onError: (error) => print('Speech error: $error'),
      onStatus: (status) => print('Speech status: $status'),
    );

    if (!available) return "";

    String resultText = "";
    bool isDone = false;

    // 3. Start listening
    await _speech.listen(
      localeId: locale,
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
      onResult: (val) {
        resultText = val.recognizedWords;
        if (val.finalResult) isDone = true;
      },
    );

    // 4. Wait for result 
    int waited = 0;
    while (!isDone && waited < 6000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waited += 200;
    }

    await _speech.stop();

    return resultText.trim();
  }

  /// Check if speech recognition is available on this device
  static Future<bool> isAvailable() async {
    return await _speech.initialize();
  }
}
