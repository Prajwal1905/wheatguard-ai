// lib/pages/field_register_page.dart

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

  // ---------------- WATERMARK ----------------
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

  // ---------------- CAPTURE PHOTOS ----------------
  Future<void> captureFarmerPhoto() async {
    if (_location == null) {
      _msg('gps_first'.tr());
      return;
    }

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

  // ---------------- LOCATION ----------------
  Future<void> _getLocation() async {
    LocationPermission p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) return;

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    setState(() => _location = pos);
  }

  // ---------------- UPLOAD ----------------
  Future<void> _upload() async {
    if (_farmerPhoto == null) return _msg('capture_farmer_first'.tr());
    if (_fieldPhoto == null) return _msg('capture_field_first'.tr());
    if (_location == null) return _msg('gps_first'.tr());
    if (_polygonPoints == null || _polygonPoints!.length < 3)
      return _msg('draw_polygon_first'.tr());

    setState(() => _loading = true);

    final polygonJson =
        jsonEncode(_polygonPoints!.map((p) => [p.latitude, p.longitude]).toList());

    var req = http.MultipartRequest(
      "POST",
      Uri.parse("${ApiService.baseUrl}/fields/"),
    );

    req.fields["farmer_id"] = "1";
    req.fields["village"] = _village.text.trim();
    req.fields["phone"] = _phone.text.trim();
    req.fields["crop"] = _crop.text.trim();
    req.fields["polygon"] = polygonJson;
    req.fields["geo_lat"] = _location!.latitude.toString();
    req.fields["geo_lon"] = _location!.longitude.toString();

    req.files.add(await http.MultipartFile.fromPath("farmer_photo", _farmerPhoto!.path));
    req.files.add(await http.MultipartFile.fromPath("field_photo", _fieldPhoto!.path));

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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('register_field'.tr()),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          TextField(
            controller: _village,
            decoration: InputDecoration(labelText: 'village'.tr()),
          ),
          TextField(
            controller: _phone,
            decoration: InputDecoration(labelText: 'phone'.tr()),
          ),
          TextField(
            controller: _crop,
            decoration: InputDecoration(labelText: 'crop'.tr()),
          ),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: () async {
              final pts = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DrawPolygonPage()),
              );
              if (pts != null && mounted) setState(() => _polygonPoints = pts);
            },
            child: Text('draw_boundary'.tr()),
          ),

          if (_polygonPoints != null)
            Text('${'points_selected'.tr()}: ${_polygonPoints!.length}',
                style: const TextStyle(color: Colors.green)),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: captureFarmerPhoto,
            child: Text('capture_farmer_photo'.tr()),
          ),
          if (_farmerPhoto != null)
            Image.file(File(_farmerPhoto!.path), height: 150),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: captureFieldPhoto,
            child: Text('capture_field_photo'.tr()),
          ),
          if (_fieldPhoto != null)
            Image.file(File(_fieldPhoto!.path), height: 150),

          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: _getLocation,
            child: Text('get_gps'.tr()),
          ),
          if (_location != null)
            Text("Lat: ${_location!.latitude}, Lon: ${_location!.longitude}"),

          const SizedBox(height: 25),

          ElevatedButton(
            onPressed: _loading ? null : _upload,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('submit_field'.tr()),
          ),
        ]),
      ),
    );
  }
}
