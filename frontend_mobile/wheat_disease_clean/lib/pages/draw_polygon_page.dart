import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DrawPolygonPage extends StatefulWidget {
  final List<LatLng>? points;

  const DrawPolygonPage({super.key, this.points});

  @override
  State<DrawPolygonPage> createState() => _DrawPolygonPageState();
}

class _DrawPolygonPageState extends State<DrawPolygonPage> {
  final MapController _map = MapController();
  List<LatLng> points = [];

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    if (widget.points != null && widget.points!.isNotEmpty) {
      points = List<LatLng>.from(widget.points!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text(
          "Draw Field Boundary",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: points.length >= 3
                  ? () => Navigator.pop(context, points)
                  : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text(
                "Save",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _green,
                disabledBackgroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: points.isNotEmpty
                  ? points.first
                  : const LatLng(20.5937, 78.9629),
              initialZoom: points.isNotEmpty ? 15 : 5,
              onTap: (tapPosition, latlng) {
                setState(() => points.add(latlng));
              },
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

              if (points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: points,
                      color: Colors.green.withOpacity(0.25),
                      borderStrokeWidth: 3,
                      borderColor: _green,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: points
                    .map(
                      (p) => Marker(
                        point: p,
                        width: 20,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),

          // Info badge top
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
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
                  points.isEmpty
                      ? "Tap on map to mark boundary points"
                      : points.length < 3
                          ? "${points.length} point${points.length > 1 ? 's' : ''} — need at least 3"
                          : "${points.length} points selected",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: points.length >= 3
                        ? _green
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: points.isNotEmpty
                    ? () => setState(() => points.removeLast())
                    : null,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text("Undo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: points.isNotEmpty
                    ? () => setState(() => points.clear())
                    : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text("Clear All"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}