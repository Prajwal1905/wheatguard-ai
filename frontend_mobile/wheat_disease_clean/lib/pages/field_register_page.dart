import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image/image.dart' as img;

import '../services/api_service.dart';
import 'draw_polygon_page.dart';

class FieldRegisterPage extends StatefulWidget {
  const FieldRegisterPage({super.key});

  @override
  State<FieldRegisterPage> createState() => _FieldRegisterPageState();
}

class _FieldRegisterPageState extends State<FieldRegisterPage> {
  final TextEditingController _village = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _crop = TextEditingController();

  XFile? _farmerPhoto;
  XFile? _fieldPhoto;
  Position? _location;
  List<LatLng>? _polygonPoints;
  bool _loading = false;

  static const _green = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  Future<File> _addWatermark(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;
    final font = img.arial24;
    final timestamp = DateTime.now().toString().substring(0, 19);
    img.drawString(image, "WheatGuard AI", font: font, x: 20, y: 20);
    img.drawString(image, "Lat: ${_location!.latitude}", font: font, x: 20, y: 60);
    img.drawString(image, "Lon: ${_location!.longitude}", font: font, x: 20, y: 100);
    img.drawString(image, "Time: $timestamp", font: font, x: 20, y: 140);
    final newPath = file.path.replaceAll(".jpg", "_wm.jpg");
    return File(newPath)..writeAsBytesSync(img.encodeJpg(image, quality: 95));
  }

  Future<void> captureFarmerPhoto() async {
    if (_location == null) { _msg('gps_first'.tr()); return; }
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x != null) {
      File wm = await _addWatermark(File(x.path));
      if (!mounted) return;
      setState(() => _farmerPhoto = XFile(wm.path));
    }
  }

  Future<void> captureFieldPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x != null && mounted) setState(() => _fieldPhoto = XFile(x.path));
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _getLocation() async {
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) return;
    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _location = pos);
  }

  Future<void> _upload() async {
    if (_farmerPhoto == null) return _msg('capture_farmer_first'.tr());
    if (_fieldPhoto == null) return _msg('capture_field_first'.tr());
    if (_location == null) return _msg('gps_first'.tr());
    if (_polygonPoints == null || _polygonPoints!.length < 3)
      return _msg('draw_polygon_first'.tr());

    setState(() => _loading = true);

    final polygonJson = jsonEncode(
        _polygonPoints!.map((p) => [p.latitude, p.longitude]).toList());

    var req = http.MultipartRequest(
        "POST", Uri.parse("${ApiService.baseUrl}/fields/"));
    req.fields["farmer_id"] = "1";
    req.fields["village"] = _village.text.trim();
    req.fields["phone"] = _phone.text.trim();
    req.fields["crop"] = _crop.text.trim();
    req.fields["polygon"] = polygonJson;
    req.fields["geo_lat"] = _location!.latitude.toString();
    req.fields["geo_lon"] = _location!.longitude.toString();
    req.files.add(await http.MultipartFile.fromPath(
        "farmer_photo", _farmerPhoto!.path));
    req.files.add(await http.MultipartFile.fromPath(
        "field_photo", _fieldPhoto!.path));

    try {
      var res = await req.send();
      var body = await res.stream.bytesToString();
      if (!mounted) return;
      setState(() => _loading = false);
      if (res.statusCode == 200) {
        _msg('field_success'.tr());
        Navigator.pop(context, true);
      } else {
        _msg('${'upload_failed'.tr()} \n$body');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg('${'connection_failed'.tr()} \n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          'register_field'.tr(),
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

            // Form Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Farm Details"),
                  const SizedBox(height: 12),
                  _inputField(_village, 'village'.tr(), Icons.location_city),
                  const SizedBox(height: 10),
                  _inputField(_phone, 'phone'.tr(), Icons.phone,
                      type: TextInputType.phone),
                  const SizedBox(height: 10),
                  _inputField(_crop, 'crop'.tr(), Icons.grass),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Polygon Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Field Boundary"),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final pts = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DrawPolygonPage()),
                        );
                        if (pts != null && mounted)
                          setState(() => _polygonPoints = pts);
                      },
                      icon: const Icon(Icons.draw),
                      label: Text('draw_boundary'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_polygonPoints != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${'points_selected'.tr()}: ${_polygonPoints!.length}',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Photos Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Photos"),
                  const SizedBox(height: 12),

                  // Farmer photo
                  _photoSection(
                    label: 'capture_farmer_photo'.tr(),
                    icon: Icons.person_outline,
                    photo: _farmerPhoto,
                    onCapture: captureFarmerPhoto,
                  ),

                  const SizedBox(height: 12),

                  // Field photo
                  _photoSection(
                    label: 'capture_field_photo'.tr(),
                    icon: Icons.landscape_outlined,
                    photo: _fieldPhoto,
                    onCapture: captureFieldPhoto,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // GPS Card
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("GPS Location"),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _getLocation,
                      icon: const Icon(Icons.gps_fixed),
                      label: Text('get_gps'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_location != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.blue, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Lat: ${_location!.latitude.toStringAsFixed(4)}, Lon: ${_location!.longitude.toStringAsFixed(4)}",
                            style: const TextStyle(
                                fontSize: 13, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _upload,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _loading ? "Uploading..." : 'submit_field'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B5E20),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _green, size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F8E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _photoSection({
    required String label,
    required IconData icon,
    required XFile? photo,
    required VoidCallback onCapture,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(photo.path),
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (photo != null) const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onCapture,
          icon: Icon(icon, size: 18),
          label: Text(photo != null ? "Retake" : label),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                photo != null ? Colors.grey.shade600 : _green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}