import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

import 'package:geolocator/geolocator.dart';

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

  @override
  void initState() {
    super.initState();

    // FOCUS priority
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

        print("Fetched markers: ${detections.length}");
      } else {
        print("Error loading map: ${res.statusCode}");
      }
    } catch (e) {
      print("Map data fetch error: $e");
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

 
  Future<void> _locateMe() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("GPS is OFF")));
      return;
    }

    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Permission denied")));
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
  }

  // -------------------------------------------------------------
  // MARKER COLOR
  // -------------------------------------------------------------
  Color _markerColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red;
      case "moderate":
      case "medium":
        return Colors.orange;
      default:
        return Colors.yellow.shade700;
    }
  }

  // -------------------------------------------------------------
  // BUILD MARKERS
  // -------------------------------------------------------------
  List<Marker> _buildMarkers() {
    return detections.map((d) {
      return Marker(
        width: 45,
        height: 45,
        point: LatLng(d["lat"], d["lon"]),
        child: GestureDetector(
          onTap: () => _showPopup(d),
          child: Icon(
            Icons.location_pin,
            color: _markerColor(d["severity"] ?? "low"),
            size: 38,
          ),
        ),
      );
    }).toList();
  }

  // -------------------------------------------------------------
  // POPUP
  // -------------------------------------------------------------
  void _showPopup(dynamic d) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(d["disease"].toString().toUpperCase()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Confidence: ${d["confidence"]}%"),
            Text("Severity: ${d["severity"]}"),
            Text("Lat: ${d["lat"]}"),
            Text("Lon: ${d["lon"]}"),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Disease Map"),
        backgroundColor: Colors.green,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _locateMe,
        child: const Icon(Icons.my_location),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
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
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",

                  // REQUIRED by OSM — identifies your app
                  userAgentPackageName: 'com.example.wheat_disease_clean',

                  // Also recommended header
                  additionalOptions: const {
                    'User-Agent': 'WheatGuardAI Student Project (Flutter)',
                  },
                ),

                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
    );
  }
}
