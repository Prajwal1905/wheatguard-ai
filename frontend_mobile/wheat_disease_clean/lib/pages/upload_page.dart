import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/tflite_service.dart';
import 'result_page.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  File?   _image;
  bool    _loading      = false;
  bool    _tfliteLoaded = false;
  bool?   _isOnline;
  String? _errorMessage;

  final WheatTFLite _tflite = WheatTFLite();

  static const _green  = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _loadTFLite();
    _checkConnectivity();
  }

  Future<void> _loadTFLite() async {
    await _tflite.loadModel();
    if (mounted) setState(() => _tfliteLoaded = true);
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = result != ConnectivityResult.none);
    }

    // Keep listening for changes
    Connectivity().onConnectivityChanged.listen((status) {
      if (mounted) {
        setState(
            () => _isOnline = status != ConnectivityResult.none);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _image        = File(picked.path);
        _errorMessage = null;
      });
    }
  }

  Future<Position?> _getLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  Future<void> _detect() async {
    if (_image == null) {
      setState(() =>
          _errorMessage = 'Please select an image first.');
      return;
    }

    setState(() {
      _loading      = true;
      _errorMessage = null;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline     = connectivity != ConnectivityResult.none;
      final now          =
          DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

      Map<String, dynamic> result;
      Position? position = await _getLocation();

      final lat = position?.latitude  ?? 0.0;
      final lon = position?.longitude ?? 0.0;

      if (isOnline) {
        // ── Online: use ONNX backend
        result = await ApiService.predictDisease(
          _image!, 'en', lat, lon,
        );

        if (result.containsKey('error')) {
          setState(() {
            _errorMessage = result['error'].toString();
            _loading      = false;
          });
          return;
        }

        // Save to Hive — already synced since server saved it
        Hive.box('predictions').add({
          'imagePath':      _image!.path,
          'disease':        result['disease'],
          'confidence':     result['confidence'],
          'severity':       result['severity'] ?? 'Low',
          'remedy':         result['remedy'],
          'ai_explanation': result['ai_explanation'],
          'timestamp':      now,
          'lat':            lat,
          'lon':            lon,
          'report_id':      result['report_id'],
          'model_version':  '19-class-efficientnet-b3-onnx',
          'synced':         true,
        });
      } else {
        // ── Offline: use TFLite ───────────────────────────────
        if (!_tfliteLoaded) {
          setState(() {
            _errorMessage =
                'Offline model is still loading. Please wait a moment.';
            _loading = false;
          });
          return;
        }

        final bytes  = await _image!.readAsBytes();
        final tflite = await _tflite.predict(bytes);

        result = {
          'disease':        tflite['predicted'] ?? 'Unknown',
          'exact_disease':  tflite['predicted'] ?? 'Unknown',
          'confidence':     tflite['confidence'] ?? 0.0,
          'severity':       _confidenceToSeverity(
              (tflite['confidence'] ?? 0.0).toDouble()),
          'remedy':
              'Connect to the internet for full remedy advice.',
          'ai_explanation':
              'AI explanation is available only when online.',
          'backend':        'TFLite-offline',
        };

        // Save to Hive — NOT synced yet
        Hive.box('predictions').add({
          'imagePath':      _image!.path,
          'disease':        result['disease'],
          'confidence':     result['confidence'],
          'severity':       result['severity'],
          'remedy':         result['remedy'],
          'ai_explanation': result['ai_explanation'],
          'timestamp':      now,
          'lat':            lat,
          'lon':            lon,
          'report_id':      null,
          'model_version':  'TFLite-offline',
          'synced':         false, // will sync when back online
        });
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ResultPage(result: result)),
      );
    } catch (e) {
      setState(() {
        _errorMessage =
            'Detection failed. Check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _confidenceToSeverity(double confidence) {
    if (confidence >= 85) return 'High';
    if (confidence >= 60) return 'Moderate';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text(
          'Wheat Disease Detection',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Connectivity indicator
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isOnline == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline!
                            ? Icons.wifi
                            : Icons.wifi_off,
                        color: _isOnline!
                            ? Colors.greenAccent
                            : Colors.red.shade200,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline! ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOnline!
                              ? Colors.greenAccent
                              : Colors.red.shade200,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Offline mode banner
            if (_isOnline == false) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.offline_bolt,
                        color: Colors.orange.shade700,
                        size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Offline mode — using on-device AI model. '
                        'Remedy advice available when online.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Error banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _errorMessage = null),
                      child: Icon(Icons.close,
                          size: 16,
                          color: Colors.red.shade400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Image preview
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _image != null
                    ? Image.file(_image!,
                        width: double.infinity,
                        fit: BoxFit.cover)
                    : Container(
                        color: Colors.white,
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 64,
                              color: Colors.green.shade300,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Select an image to detect disease',
                              style: TextStyle(
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Camera / Gallery buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _pickImage(ImageSource.gallery),
                    icon: const Icon(
                        Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Detect button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _detect,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2),
                      )
                    : Icon(
                        _isOnline == false
                            ? Icons.memory
                            : Icons.search,
                      ),
                label: Text(
                  _loading
                      ? 'Analyzing…'
                      : _isOnline == false
                          ? 'Detect (offline)'
                          : 'Detect Disease',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
