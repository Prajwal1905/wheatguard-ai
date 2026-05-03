import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import 'result_page.dart';
import 'history_page.dart';
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

class _HomePageState extends State<HomePage> {
  File? _selectedImage;
  bool _loading = false;

  static const _green = Color(0xFF2E7D32);
  static const _orange = Color(0xFFE65100);
  static const _bg = Color(0xFFF1F8E9);

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _detectDisease() async {
    if (_selectedImage == null) {
      _showSnack(tr('upload_image'));
      return;
    }

    setState(() => _loading = true);

    try {
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
      _showSnack("Error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goto(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageCard(),
            const SizedBox(height: 20),
            _buildDetectButton(),
            const SizedBox(height: 28),
            _buildSectionTitle("Quick Actions"),
            const SizedBox(height: 12),
            _buildActionsGrid(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _green,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.grass, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            tr('app_title'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: DropdownButton<Locale>(
            value: context.locale,
            underline: const SizedBox(),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.language, color: Colors.white, size: 22),
            items: const [
              DropdownMenuItem(value: Locale('en'), child: Text('EN')),
              DropdownMenuItem(value: Locale('hi'), child: Text('HI')),
              DropdownMenuItem(value: Locale('mr'), child: Text('MR')),
            ],
            onChanged: (locale) => context.setLocale(locale!),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCard() {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _selectedImage != null
                ? Image.file(
                    _selectedImage!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xFFF1F8E9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 60,
                          color: Colors.green.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Tap below to add image",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _imageButton(
                  icon: Icons.camera_alt_outlined,
                  label: tr('capture'),
                  color: _green,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _imageButton(
                  icon: Icons.photo_library_outlined,
                  label: tr('gallery'),
                  color: const Color(0xFF00796B),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildDetectButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _detectDisease,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.search, size: 22),
        label: Text(
          _loading ? "Analyzing..." : tr('detect_btn'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B5E20),
      ),
    );
  }

  Widget _buildActionsGrid() {
    final actions = [
      _ActionItem(Icons.history_rounded, tr('view_history'),
          const Color(0xFF1565C0), const HistoryPage()),
      _ActionItem(Icons.map_outlined, tr('disease_map'),
          const Color(0xFF2E7D32), const MapPage()),
      _ActionItem(Icons.notifications_outlined, tr('alerts'),
          const Color(0xFFBF360C), const AlertsPage()),
      _ActionItem(Icons.history_edu_outlined, tr('view_alert_history'),
          const Color(0xFFE65100), const AlertHistoryPage()),
      _ActionItem(Icons.agriculture_outlined, tr('register_field_btn'),
          const Color(0xFF4E342E), const FieldRegisterPage()),
      _ActionItem(Icons.grid_view_outlined, tr('view_fields_btn'),
          const Color(0xFF37474F), const FieldListPage()),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.8,
      children: actions.map((a) => _buildGridButton(a)).toList(),
    );
  }

  Widget _buildGridButton(_ActionItem item) {
    return InkWell(
      onTap: () => _goto(item.page),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.color.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: item.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final Widget page;
  _ActionItem(this.icon, this.label, this.color, this.page);
}