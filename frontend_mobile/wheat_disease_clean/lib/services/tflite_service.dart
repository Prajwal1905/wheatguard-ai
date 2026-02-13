import 'dart:typed_data';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class WheatTFLite {
  late Interpreter interpreter;

  final int inputSize = 380;
  final int numClasses = 19;

  final List<double> mean = [0.485, 0.456, 0.406];
  final List<double> std = [0.229, 0.224, 0.225];

  Future<void> loadModel() async {
    final options = InterpreterOptions();
    options.threads = 2;

    interpreter = await Interpreter.fromAsset(
      'assets/models/wheat_disease_b3_float16.tflite',
      options: options,
    );

    print("TFLite model loaded.");
  }

  /// Preprocess image to match EfficientNet format
  List<List<List<List<double>>>> preprocess(img.Image image) {
    img.Image resized =
        img.copyResize(image, width: inputSize, height: inputSize);

    return [
      List.generate(inputSize, (y) {
        return List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);

          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;

          return [
            (r - mean[0]) / std[0],
            (g - mean[1]) / std[1],
            (b - mean[2]) / std[2],
          ];
        });
      })
    ];
  }

  Future<Map<String, dynamic>> predict(Uint8List imageBytes) async {
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      return {"error": "Invalid image"};
    }

    final input = preprocess(image);

    // Correct output shape [1, 19]
    final output =
        List.generate(1, (_) => List.filled(numClasses, 0.0));

    interpreter.run(input, output);

    final logits = output[0];
    final probabilities = _softmax(logits);

    final index = _argmax(probabilities);

    return {
      "predicted": DISEASE_CLASSES[index],
      "confidence": probabilities[index] * 100,
      "index": index,
      "backend": "TFLite-offline"
    };
  }

  List<double> _softmax(List<double> values) {
    final maxVal = values.reduce(max);
    final expVals = values.map((v) => exp(v - maxVal)).toList();
    final sum = expVals.reduce((a, b) => a + b);
    return expVals.map((v) => v / sum).toList();
  }

  int _argmax(List<double> values) {
    double maxValue = values[0];
    int maxIndex = 0;

    for (int i = 1; i < values.length; i++) {
      if (values[i] > maxValue) {
        maxValue = values[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }
}

const List<String> DISEASE_CLASSES = [
  "Aphid",
  "Black Rust",
  "Blast",
  "Brown Rust",
  "Common Root Rot",
  "Fusarium Head Blight",
  "Leaf Blight",
  "Mildew",
  "Mite",
  "Septoria",
  "Smut",
  "Stem fly",
  "Tan spot",
  "Yellow Rust",
  "BYDV",
  "Black_Chaff",
  "Karnal_Bunt",
  "Powdery_Mildew",
  "Healthy",
];
