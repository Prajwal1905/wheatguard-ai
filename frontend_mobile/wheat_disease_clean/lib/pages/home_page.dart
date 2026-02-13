import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import 'result_page.dart';
import 'history_page.dart';
import 'package:geolocator/geolocator.dart';
import 'map_page.dart';
import 'alerts_page.dart';
import 'alert_history_page.dart';
import 'field_register_page.dart';
import 'field_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _loading = false;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _detectDisease() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('upload_image'))));
      return;
    }

    setState(() => _loading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final langCode = context.locale.languageCode;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final result = await ApiService.predictDisease(
        _selectedImage!,
        langCode,
        position.latitude,
        position.longitude,
      );

      final box = Hive.box('predictions');
      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      box.add({
        'imagePath': _selectedImage!.path,
        'disease': result['disease'],
        'confidence': result['confidence'],
        'remedy': result['remedy'],
        'ai_explanation': result['ai_explanation'],
        'timestamp': now,
        'lat': position.latitude,
        'lon': position.longitude,
        'report_id': result['report_id'],
        'synced': false,
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(result: result)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ Error: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.green.shade700;
    final lightGreen = Colors.green.shade400;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor, lightGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Text(
          tr('app_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButton<Locale>(
              value: context.locale,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              icon: const Icon(Icons.language, color: Colors.white),
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
                DropdownMenuItem(value: Locale('hi'), child: Text('हिन्दी')),
                DropdownMenuItem(value: Locale('mr'), child: Text('मराठी')),
              ],
              onChanged: (locale) async {
                await context.setLocale(locale!);
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tr('upload_image'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: themeColor,
              ),
            ),
            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  Container(
                    height: 220,
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: themeColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.image,
                            size: 100,
                            color: Colors.grey,
                          ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: Text(tr('capture')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: Text(tr('gallery')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ScaleTransition(
              scale: _pulseController ?? const AlwaysStoppedAnimation(1.0),

              child: ElevatedButton(
                onPressed: _loading ? null : _detectDisease,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 16,
                  ),
                  elevation: 6,
                  shadowColor: Colors.orange.shade200,
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        tr('detect_btn'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                _buildActionButton(
                  Icons.history,
                  tr('view_history'),
                  Colors.blueAccent,
                  const HistoryPage(),
                ),
                _buildActionButton(
                  Icons.map,
                  tr('disease_map'),
                  Colors.green.shade700,
                  const MapPage(),
                ),
                _buildActionButton(
                  Icons.notifications_active,
                  tr('alerts'),
                  Colors.deepOrangeAccent,
                  const AlertsPage(),
                ),
                _buildActionButton(
                  Icons.history_edu,
                  tr('view_alert_history'),
                  Colors.orange.shade600,
                  const AlertHistoryPage(),
                ),
                _buildActionButton(
                  Icons.agriculture_rounded,
                  tr('register_field_btn'),
                  Colors.brown.shade600,
                  const FieldRegisterPage(),
                ),

                _buildActionButton(
                  Icons.agriculture,
                  tr('view_fields_btn'),
                  Colors.brown,
                  const FieldListPage(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    Widget page,
  ) {
    return ElevatedButton.icon(
      onPressed: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        elevation: 3,
      ),
    );
  }
}
