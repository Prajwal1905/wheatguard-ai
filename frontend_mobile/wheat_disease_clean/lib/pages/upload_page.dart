import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import '../services/api_service.dart';
import '../services/tflite_service.dart';
import 'result_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  File? _image;
  bool _loading = false;

  final WheatTFLite _tflite = WheatTFLite();
  bool _tfliteLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTFLite();
  }

  Future<void> _loadTFLite() async {
    await _tflite.loadModel();
    setState(() => _tfliteLoaded = true);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) return;

    setState(() => _loading = true);

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity != ConnectivityResult.none;

      String lang = "en";
      final bytes = await _image!.readAsBytes();

      Map<String, dynamic> result;

      if (isOnline) {
        print(" Online → using backend ONNX");

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        result = await ApiService.predictDisease(
          _image!,
          lang,
          position.latitude,
          position.longitude,
        );
      } else {
        print("📴 Offline → using TFLite");

        if (!_tfliteLoaded) {
          throw "TFLite model not loaded.";
        }

        result = await _tflite.predict(bytes);

        result["remedy"] =
            "Offline mode: remedy available only online.";
        result["ai_explanation"] =
            "Connect to internet to get full explanation.";
        result["backend"] = "TFLite-offline";
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(result: result),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Wheat Disease Detection")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_image != null)
              Image.file(_image!, height: 200)
            else
              Container(
                height: 200,
                width: 200,
                color: Colors.grey[300],
                child: Icon(
                  Icons.image,
                  size: 100,
                  color: Colors.grey[700],
                ),
              ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo),
                  label: Text("Gallery"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _uploadImage,
              child: _loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text("Detect Disease"),
            ),
          ],
        ),
      ),
    );
  }
}
