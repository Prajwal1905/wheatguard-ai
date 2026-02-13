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

  @override
  void initState() {
    super.initState();

    village = TextEditingController(text: widget.field["village"]);
    phone = TextEditingController(text: widget.field["phone"]);
    crop = TextEditingController(text: widget.field["crop"]);

    polygonPoints = (widget.field["polygon"] as List)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();

    newLat = (widget.field["geo_lat"] as num).toDouble();
    newLon = (widget.field["geo_lon"] as num).toDouble();
  }

  // ---------------- PICKERS ----------------

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

  // ---------------- SAVE ----------------

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
      "PUT",
      Uri.parse("${ApiService.baseUrl}/fields/$id"),
    );

    req.fields["farmer_id"] = widget.field["farmer_id"].toString();
    req.fields["village"] = village.text;
    req.fields["phone"] = phone.text;
    req.fields["crop"] = crop.text;

    req.fields["geo_lat"] = newLat.toString();
    req.fields["geo_lon"] = newLon.toString();

    req.fields["polygon"] = jsonEncode(
      polygonPoints.map((p) => [p.latitude, p.longitude]).toList(),
    );

    if (newFarmerPhoto != null) {
      req.files.add(await http.MultipartFile.fromPath("farmer_photo", newFarmerPhoto!.path));
    }

    if (newFieldPhoto != null) {
      req.files.add(await http.MultipartFile.fromPath("field_photo", newFieldPhoto!.path));
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final farmerUrl = widget.field["photo_url"] != null
        ? "${ApiService.baseUrl}${widget.field["photo_url"]}"
        : null;

    final fieldUrl = widget.field["field_photo_url"] != null
        ? "${ApiService.baseUrl}${widget.field["field_photo_url"]}"
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('edit_field'.tr()),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          TextField(
            controller: village,
            decoration: InputDecoration(labelText: 'village'.tr()),
          ),
          TextField(
            controller: phone,
            decoration: InputDecoration(labelText: 'phone'.tr()),
          ),
          TextField(
            controller: crop,
            decoration: InputDecoration(labelText: 'crop'.tr()),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () async {
              final pts = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DrawPolygonPage(points: polygonPoints)),
              );
              if (pts != null) setState(() => polygonPoints = pts);
            },
            child: Text('edit_polygon'.tr()),
          ),

          const SizedBox(height: 20),

          Text('farmer_photo'.tr()),
          newFarmerPhoto != null
              ? Image.file(File(newFarmerPhoto!.path), height: 120)
              : farmerUrl != null
                  ? Image.network(farmerUrl, height: 120)
                  : const Icon(Icons.person, size: 60),

          ElevatedButton(
            onPressed: pickFarmerPhoto,
            child: Text('change_farmer_photo'.tr()),
          ),

          const SizedBox(height: 20),

          Text('field_photo'.tr()),
          newFieldPhoto != null
              ? Image.file(File(newFieldPhoto!.path), height: 120)
              : fieldUrl != null
                  ? Image.network(fieldUrl, height: 120)
                  : const Icon(Icons.landscape, size: 60),

          ElevatedButton(
            onPressed: pickFieldPhoto,
            child: Text('change_field_photo'.tr()),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: pickLocation,
            child: Text('update_gps'.tr()),
          ),

          if (newLat != null && newLon != null)
            Text("Lat: $newLat, Lon: $newLon"),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: loading ? null : saveUpdates,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48)),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('save_changes'.tr()),
          ),
        ]),
      ),
    );
  }
}
