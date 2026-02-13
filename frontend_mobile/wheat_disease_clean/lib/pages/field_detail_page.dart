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

  // ---------------- POLYGON ----------------
  List<LatLng> _parsePolygon(dynamic poly) {
    if (poly == null) return [];
    try {
      final pts = poly as List<dynamic>;
      return pts
          .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------- AREA ----------------
  double _computeAreaSqM(List<LatLng> points) {
    if (points.length < 3) return 0;

    const double R = 6371000;
    double lat0 =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
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

  // ---------------- UI ----------------
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

    final areaSqM = polygon.isEmpty ? 0 : _computeAreaSqM(polygon);
    final areaHectares = areaSqM / 10000;
    final areaAcres = areaSqM / 4046.85642;

    return Scaffold(
      appBar: AppBar(
        title: Text("${'edit_field'.tr()} #${field["id"] ?? ""}"),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FieldEditPage(field: field)),
              );
            },
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // PHOTOS
          Row(
            children: [
              Expanded(
                child: _ImageCard(
                  title: 'farmer_photo'.tr(),
                  url: farmerPhotoUrl,
                  icon: Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ImageCard(
                  title: 'field_photo'.tr(),
                  url: fieldPhotoUrl,
                  icon: Icons.landscape,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // INFO CARD
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info('village'.tr(), field["village"]),
                  _info('phone'.tr(), field["phone"]),
                  _info('crop'.tr(), field["crop"]),
                  _info("ID", "${field["farmer_id"]}"),
                  if (lat != null && lon != null)
                    _info("GPS", "Lat: $lat, Lon: $lon"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 15),

          // AREA CARD
          if (polygon.isNotEmpty)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('field_area'.tr(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("${'sq_meters'.tr()}: ${areaSqM.toStringAsFixed(2)}"),
                    Text("${'hectares'.tr()}: ${areaHectares.toStringAsFixed(4)}"),
                    Text("${'acres'.tr()}: ${areaAcres.toStringAsFixed(4)}"),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // MAP BUTTON
          if (polygon.isNotEmpty && lat != null && lon != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FieldMapPage(
                      polygon: polygon,
                      center: LatLng(lat, lon),
                      fieldId: field["id"] ?? 0,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: Text('view_field_map'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

          const SizedBox(height: 20),

          // DELETE BUTTON
          ElevatedButton.icon(
            onPressed: () async {
              final url = Uri.parse("${ApiService.baseUrl}/fields/${field["id"]}");
              final res = await http.delete(url);

              if (res.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('field_deleted'.tr())),
                );
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.delete),
            label: Text('delete_field'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value ?? "-")),
        ],
      ),
    );
  }
}

// IMAGE CARD
class _ImageCard extends StatelessWidget {
  final String title;
  final String? url;
  final IconData icon;

  const _ImageCard({required this.title, required this.url, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 5),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: url == null
                ? Container(color: Colors.grey.shade200, child: Icon(icon, size: 40))
                : Image.network(url!, fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }
}
