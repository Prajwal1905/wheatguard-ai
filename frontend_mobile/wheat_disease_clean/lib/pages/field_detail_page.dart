import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';

import 'field_map_page.dart';
import 'field_edit_page.dart';
import '../services/api_service.dart';

class FieldDetailPage extends StatelessWidget {
  final Map<String, dynamic> field;
  const FieldDetailPage({super.key, required this.field});

  static const _green = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  List<LatLng> _parsePolygon(dynamic poly) {
    if (poly == null) return [];
    try {
      final pts = poly as List<dynamic>;
      return pts
          .map((p) => LatLng(
              (p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  double _computeAreaSqM(List<LatLng> points) {
    if (points.length < 3) return 0;
    const double R = 6371000;
    double lat0 =
        points.map((p) => p.latitude).reduce((a, b) => a + b) /
            points.length;
    lat0 = lat0 * pi / 180;
    List<Offset> mpts = points.map((p) {
      double x = R * p.longitude * pi / 180 * cos(lat0);
      double y = R * p.latitude * pi / 180;
      return Offset(x, y);
    }).toList();
    double sum = 0;
    for (int i = 0; i < mpts.length; i++) {
      final p1 = mpts[i];
      final p2 = mpts[(i + 1) % mpts.length];
      sum += (p1.dx * p2.dy) - (p2.dx * p1.dy);
    }
    return (sum.abs() / 2.0);
  }

  @override
  Widget build(BuildContext context) {
    final polygon = _parsePolygon(field["polygon"]);
    final farmerPhotoUrl = field["photo_url"] != null
        ? "${ApiService.baseUrl}${field["photo_url"]}"
        : null;
    final fieldPhotoUrl = field["field_photo_url"] != null
        ? "${ApiService.baseUrl}${field["field_photo_url"]}"
        : null;
    final lat = (field["geo_lat"] as num?)?.toDouble();
    final lon = (field["geo_lon"] as num?)?.toDouble();
    final areaSqM =
        polygon.isEmpty ? 0.0 : _computeAreaSqM(polygon);
    final areaHectares = areaSqM / 10000;
    final areaAcres = areaSqM / 4046.85642;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          "Field #${field["id"] ?? ""}",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FieldEditPage(field: field)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Photos
          Row(
            children: [
              Expanded(
                child: _photoCard(
                  title: 'farmer_photo'.tr(),
                  url: farmerPhotoUrl,
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _photoCard(
                  title: 'field_photo'.tr(),
                  url: fieldPhotoUrl,
                  icon: Icons.landscape_outlined,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Info Card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardTitle("Farm Information"),
                const SizedBox(height: 10),
                _infoRow(Icons.location_city, 'village'.tr(),
                    field["village"]),
                _infoRow(Icons.phone, 'phone'.tr(), field["phone"]),
                _infoRow(Icons.grass, 'crop'.tr(), field["crop"]),
                _infoRow(Icons.badge, "Farmer ID",
                    "${field["farmer_id"]}"),
                if (lat != null && lon != null)
                  _infoRow(Icons.gps_fixed, "GPS",
                      "Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Area Card
          if (polygon.isNotEmpty)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardTitle('field_area'.tr()),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _areaChip(
                              "Sq. Meters",
                              areaSqM.toStringAsFixed(0))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _areaChip(
                              "Hectares",
                              areaHectares.toStringAsFixed(4))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _areaChip(
                              "Acres",
                              areaAcres.toStringAsFixed(4))),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // View Map Button
          if (polygon.isNotEmpty && lat != null && lon != null)
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FieldMapPage(
                      polygon: polygon,
                      center: LatLng(lat, lon),
                      fieldId: field["id"] ?? 0,
                    ),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
                label: Text('view_field_map'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Delete Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    title: const Text("Delete Field"),
                    content: const Text(
                        "Are you sure you want to delete this field?"),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text("Delete"),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final url = Uri.parse(
                      "${ApiService.baseUrl}/fields/${field["id"]}");
                  final res = await http.delete(url);
                  if (res.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('field_deleted'.tr())),
                    );
                    Navigator.pop(context, true);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: Text('delete_field'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
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

  Widget _cardTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _darkGreen,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
                fontSize: 13, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value ?? "-",
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _photoCard({
    required String title,
    required String? url,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: url == null
                ? Container(
                    color: Colors.grey.shade100,
                    child: Icon(icon,
                        size: 40, color: Colors.grey.shade400),
                  )
                : Image.network(url, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}