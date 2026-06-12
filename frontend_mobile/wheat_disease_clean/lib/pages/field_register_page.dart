import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:image/image.dart' as img;
import 'package:device_info_plus/device_info_plus.dart';

import '../services/api_service.dart';
import 'draw_polygon_page.dart';

class FieldRegisterPage extends StatefulWidget {
  const FieldRegisterPage({super.key});

  @override
  State<FieldRegisterPage> createState() => _FieldRegisterPageState();
}

class _FieldRegisterPageState extends State<FieldRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _village = TextEditingController();
  final TextEditingController _phone   = TextEditingController();
  final TextEditingController _crop    = TextEditingController();

  XFile?       _farmerPhoto;
  XFile?       _fieldPhoto;
  Position?    _location;
  List<LatLng>? _polygonPoints;
  bool         _loading  = false;
  int?         _farmerId; // derived from device ID hash

  static const _green     = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _loadFarmerId();
  }

  @override
  void dispose() {
    _village.dispose();
    _phone.dispose();
    _crop.dispose();
    super.dispose();
  }

  /// Derives a stable farmer ID from the device ID.
  /// This ensures every device always gets the same ID
  /// without needing a login system on the mobile app.
  Future<void> _loadFarmerId() async {
    try {
      final deviceId = await ApiService.getDeviceId();
      // Use last 6 digits of device ID hash as farmer ID
      final hash = deviceId.hashCode.abs() % 999999 + 1;
      if (mounted) setState(() => _farmerId = hash);
    } catch (e) {
      // Fallback — use timestamp-based ID
      if (mounted) {
        setState(() =>
            _farmerId = DateTime.now().millisecondsSinceEpoch % 999999);
      }
    }
  }

  Future<File> _addWatermark(File file) async {
    if (_location == null) return file;
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    final font      = img.arial24;
    final timestamp = DateTime.now().toString().substring(0, 19);

    img.drawString(image, 'WheatGuard AI',
        font: font, x: 20, y: 20,
        color: img.ColorRgb8(255, 255, 255));
    img.drawString(image,
        'Lat: ${_location!.latitude.toStringAsFixed(4)}',
        font: font, x: 20, y: 60,
        color: img.ColorRgb8(255, 255, 0));
    img.drawString(image,
        'Lon: ${_location!.longitude.toStringAsFixed(4)}',
        font: font, x: 20, y: 100,
        color: img.ColorRgb8(255, 255, 0));
    img.drawString(image, 'Time: $timestamp',
        font: font, x: 20, y: 140,
        color: img.ColorRgb8(0, 255, 255));

    final newPath = file.path.replaceAll('.jpg', '_wm.jpg');
    return File(newPath)
      ..writeAsBytesSync(img.encodeJpg(image, quality: 95));
  }

  Future<void> _captureFarmerPhoto() async {
    if (_location == null) {
      _msg('gps_first'.tr());
      return;
    }
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera);
    if (x != null) {
      final wm = await _addWatermark(File(x.path));
      if (mounted) setState(() => _farmerPhoto = XFile(wm.path));
    }
  }

  Future<void> _captureFieldPhoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.camera);
    if (x != null && mounted) {
      setState(() => _fieldPhoto = XFile(x.path));
    }
  }

  void _msg(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _getLocation() async {
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      _msg('Location permission denied.');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _location = pos);
    } catch (_) {
      _msg('Could not get location. Try again.');
    }
  }

  Future<void> _upload() async {
    // Validate form fields
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_farmerPhoto == null) {
      _msg('capture_farmer_first'.tr());
      return;
    }
    if (_fieldPhoto == null) {
      _msg('capture_field_first'.tr());
      return;
    }
    if (_location == null) {
      _msg('gps_first'.tr());
      return;
    }
    if (_polygonPoints == null || _polygonPoints!.length < 3) {
      _msg('draw_polygon_first'.tr());
      return;
    }
    if (_farmerId == null) {
      _msg('Device ID not ready. Please wait a moment.');
      return;
    }

    setState(() => _loading = true);

    final polygonJson = jsonEncode(
        _polygonPoints!
            .map((p) => [p.latitude, p.longitude])
            .toList());

    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/fields/'));

    req.fields['farmer_id'] = _farmerId.toString(); // fixed
    req.fields['village']   = _village.text.trim();
    req.fields['phone']     = _phone.text.trim();
    req.fields['crop']      = _crop.text.trim();
    req.fields['polygon']   = polygonJson;
    req.fields['geo_lat']   = _location!.latitude.toString();
    req.fields['geo_lon']   = _location!.longitude.toString();

    req.files.add(await http.MultipartFile.fromPath(
        'farmer_photo', _farmerPhoto!.path));
    req.files.add(await http.MultipartFile.fromPath(
        'field_photo', _fieldPhoto!.path));

    try {
      final res  = await req.send();
      final body = await res.stream.bytesToString();

      if (!mounted) return;
      setState(() => _loading = false);

      if (res.statusCode == 200) {
        _showSuccessDialog();
      } else {
        _msg('${'upload_failed'.tr()}: $body');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg('${'connection_failed'.tr()}: $e');
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF2E7D32), size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'field_success'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your field has been registered successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, true); // back to prev page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // Farmer ID indicator
              if (_farmerId != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined,
                          size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Text(
                        'Your Farmer ID: $_farmerId',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Farm details
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Farm Details'),
                    const SizedBox(height: 12),
                    _validatedField(
                      _village,
                      'village'.tr(),
                      Icons.location_city,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Village name is required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _validatedField(
                      _phone,
                      'phone'.tr(),
                      Icons.phone,
                      type: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Phone number is required';
                        if (!RegExp(r'^[6-9]\d{9}$')
                            .hasMatch(v.trim()))
                          return 'Enter a valid 10-digit Indian mobile number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _validatedField(
                      _crop,
                      'crop'.tr(),
                      Icons.grass,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Crop name is required'
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Polygon
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Field Boundary'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final pts = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const DrawPolygonPage()),
                          );
                          if (pts != null && mounted) {
                            setState(
                                () => _polygonPoints = pts);
                          }
                        },
                        icon: const Icon(Icons.draw),
                        label: Text('draw_boundary'.tr()),
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
                    if (_polygonPoints != null) ...[
                      const SizedBox(height: 8),
                      _statusChip(
                        icon: Icons.check_circle,
                        label:
                            '${_polygonPoints!.length} boundary points selected',
                        color: Colors.green,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Photos
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Photos'),
                    const SizedBox(height: 12),
                    _photoSection(
                      label: 'capture_farmer_photo'.tr(),
                      icon: Icons.person_outline,
                      photo: _farmerPhoto,
                      onCapture: _captureFarmerPhoto,
                    ),
                    const SizedBox(height: 12),
                    _photoSection(
                      label: 'capture_field_photo'.tr(),
                      icon: Icons.landscape_outlined,
                      photo: _fieldPhoto,
                      onCapture: _captureFieldPhoto,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // GPS
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('GPS Location'),
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (_location != null) ...[
                      const SizedBox(height: 8),
                      _statusChip(
                        icon: Icons.location_on,
                        label:
                            'Lat: ${_location!.latitude.toStringAsFixed(4)}, '
                            'Lon: ${_location!.longitude.toStringAsFixed(4)}',
                        color: Colors.blue,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Submit
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _upload,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _loading
                        ? 'Uploading…'
                        : 'submit_field'.tr(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
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
        color: _darkGreen,
      ),
    );
  }

  Widget _validatedField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _green, size: 20),
        filled: true,
        fillColor: const Color(0xFFF1F8E9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.red.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.shade700, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 12, color: color.shade800),
            ),
          ),
        ],
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
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (photo != null) const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onCapture,
          icon: Icon(photo != null ? Icons.refresh : icon,
              size: 18),
          label: Text(photo != null ? 'Retake' : label),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                photo != null ? Colors.grey.shade600 : _green,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
