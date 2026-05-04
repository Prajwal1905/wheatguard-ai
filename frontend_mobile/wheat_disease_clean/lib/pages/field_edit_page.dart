import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

import '../services/api_service.dart';
import 'draw_polygon_page.dart';

class FieldEditPage extends StatefulWidget {
  final Map field;
  const FieldEditPage({super.key, required this.field});

  @override
  State<FieldEditPage> createState() => _FieldEditPageState();
}

class _FieldEditPageState extends State<FieldEditPage> {
  late TextEditingController village;
  late TextEditingController phone;
  late TextEditingController crop;

  XFile? newFarmerPhoto;
  XFile? newFieldPhoto;
  List<LatLng> polygonPoints = [];
  double? newLat;
  double? newLon;
  bool loading = false;

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    village = TextEditingController(text: widget.field["village"]);
    phone = TextEditingController(text: widget.field["phone"]);
    crop = TextEditingController(text: widget.field["crop"]);
    polygonPoints = (widget.field["polygon"] as List)
        .map((p) => LatLng(
            (p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    newLat = (widget.field["geo_lat"] as num).toDouble();
    newLon = (widget.field["geo_lon"] as num).toDouble();
  }

  Future<void> pickFarmerPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (img != null) setState(() => newFarmerPhoto = img);
  }

  Future<void> pickFieldPhoto() async {
    final img = await ImagePicker().pickImage(source: ImageSource.camera);
    if (img != null) setState(() => newFieldPhoto = img);
  }

  Future<void> pickLocation() async {
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      newLat = pos.latitude;
      newLon = pos.longitude;
    });
  }

  Future<void> saveUpdates() async {
    if (newLat == null || newLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('location_missing'.tr())),
      );
      return;
    }
    setState(() => loading = true);
    final id = widget.field["id"];
    var req = http.MultipartRequest(
        "PUT", Uri.parse("${ApiService.baseUrl}/fields/$id"));
    req.fields["farmer_id"] = widget.field["farmer_id"].toString();
    req.fields["village"] = village.text;
    req.fields["phone"] = phone.text;
    req.fields["crop"] = crop.text;
    req.fields["geo_lat"] = newLat.toString();
    req.fields["geo_lon"] = newLon.toString();
    req.fields["polygon"] = jsonEncode(
        polygonPoints.map((p) => [p.latitude, p.longitude]).toList());
    if (newFarmerPhoto != null) {
      req.files.add(await http.MultipartFile.fromPath(
          "farmer_photo", newFarmerPhoto!.path));
    }
    if (newFieldPhoto != null) {
      req.files.add(await http.MultipartFile.fromPath(
          "field_photo", newFieldPhoto!.path));
    }
    final res = await req.send();
    final body = await res.stream.bytesToString();
    setState(() => loading = false);
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('update_success'.tr())),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${'update_failed'.tr()}: $body")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmerUrl = widget.field["photo_url"] != null
        ? "${ApiService.baseUrl}${widget.field["photo_url"]}"
        : null;
    final fieldUrl = widget.field["field_photo_url"] != null
        ? "${ApiService.baseUrl}${widget.field["field_photo_url"]}"
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          'edit_field'.tr(),
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

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Farm Details"),
                  const SizedBox(height: 12),
                  _inputField(village, 'village'.tr(), Icons.location_city),
                  const SizedBox(height: 10),
                  _inputField(phone, 'phone'.tr(), Icons.phone,
                      type: TextInputType.phone),
                  const SizedBox(height: 10),
                  _inputField(crop, 'crop'.tr(), Icons.grass),
                ],
              ),
            ),

            const SizedBox(height: 12),

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
                              builder: (_) => DrawPolygonPage(
                                  points: polygonPoints)),
                        );
                        if (pts != null)
                          setState(() => polygonPoints = pts);
                      },
                      icon: const Icon(Icons.edit_location_alt),
                      label: Text('edit_polygon'.tr()),
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Photos"),
                  const SizedBox(height: 12),
                  Text('farmer_photo'.tr(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: newFarmerPhoto != null
                        ? Image.file(File(newFarmerPhoto!.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover)
                        : farmerUrl != null
                            ? Image.network(farmerUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Container(
                                height: 80,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.person,
                                    size: 40, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: pickFarmerPhoto,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text('change_farmer_photo'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text('field_photo'.tr(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: newFieldPhoto != null
                        ? Image.file(File(newFieldPhoto!.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover)
                        : fieldUrl != null
                            ? Image.network(fieldUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Container(
                                height: 80,
                                color: Colors.grey.shade100,
                                child: const Icon(Icons.landscape,
                                    size: 40, color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: pickFieldPhoto,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text('change_field_photo'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("GPS Location"),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: pickLocation,
                      icon: const Icon(Icons.gps_fixed),
                      label: Text('update_gps'.tr()),
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
                  if (newLat != null && newLon != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(
                        "Lat: ${newLat!.toStringAsFixed(4)}, Lon: ${newLon!.toStringAsFixed(4)}",
                        style: const TextStyle(
                            fontSize: 13, color: Colors.blue),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: loading ? null : saveUpdates,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  loading ? "Saving..." : 'save_changes'.tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
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
}