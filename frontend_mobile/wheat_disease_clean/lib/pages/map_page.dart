import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class MapPage extends StatefulWidget {
  final double? focusLat;
  final double? focusLon;
  final double? alertLat;
  final double? alertLon;
  final double? alertRadiusKm;
  final String? diseaseName;

  const MapPage({
    this.focusLat,
    this.focusLon,
    this.alertLat,
    this.alertLon,
    this.alertRadiusKm,
    this.diseaseName,
    super.key,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  List<dynamic> detections = [];
  LatLng initialCenter = const LatLng(20.5937, 78.9629);
  double initialZoom = 5.0;
  bool loading = true;

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    final double? lat = widget.focusLat ?? widget.alertLat;
    final double? lon = widget.focusLon ?? widget.alertLon;
    if (lat != null && lon != null) {
      initialCenter = LatLng(lat, lon);
      initialZoom = 15;
    }
    _fetchMapData();
  }

  Future<void> _fetchMapData() async {
    try {
      final url = Uri.parse("${ApiService.baseUrl}/detections/map_data");
      final res = await http.get(url);
      if (res.statusCode == 200) {
        detections = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint("Map data fetch error: $e");
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _locateMe() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS is OFF")),
      );
      return;
    }
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Permission denied")),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
  }

  Color _markerColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red.shade700;
      case "moderate":
      case "medium":
        return Colors.orange.shade700;
      default:
        return Colors.green.shade600;
    }
  }

  void _showPopup(dynamic d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: _markerColor(d["severity"] ?? "low")),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                d["disease"].toString(),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _popupRow("Confidence", "${d["confidence"]}%"),
            _popupRow("Severity", d["severity"] ?? "-"),
            _popupRow("Latitude", "${d["lat"]}"),
            _popupRow("Longitude", "${d["lon"]}"),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _popupRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text("$label: ",
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return detections.map((d) {
      final color = _markerColor(d["severity"] ?? "low");
      return Marker(
        width: 45,
        height: 45,
        point: LatLng(d["lat"], d["lon"]),
        child: GestureDetector(
          onTap: () => _showPopup(d),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Icon(Icons.location_on, color: color, size: 24),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text(
          "Disease Map",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => loading = true);
              _fetchMapData();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _locateMe,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: initialZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName:
                          'com.example.wheat_disease_clean',
                      additionalOptions: const {
                        'User-Agent':
                            'WheatGuardAI Student Project (Flutter)',
                      },
                    ),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),

                // Detection count badge
                if (detections.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        "${detections.length} Detections",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}