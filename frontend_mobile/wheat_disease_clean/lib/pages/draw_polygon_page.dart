// lib/pages/draw_polygon_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DrawPolygonPage extends StatefulWidget {
  final List<LatLng>? points;   // Accept old polygon points

  const DrawPolygonPage({super.key, this.points});

  @override
  State<DrawPolygonPage> createState() => _DrawPolygonPageState();
}

class _DrawPolygonPageState extends State<DrawPolygonPage> {
  final MapController _map = MapController();

  List<LatLng> points = [];

  @override
  void initState() {
    super.initState();

    // If editing existing polygon → load it
    if (widget.points != null && widget.points!.isNotEmpty) {
      points = List<LatLng>.from(widget.points!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Draw Field Boundary"),
        backgroundColor: Colors.green,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, points),
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),

      body: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: points.isNotEmpty
              ? points.first
              : const LatLng(20.5937, 78.9629), // India default
          initialZoom: points.isNotEmpty ? 15 : 5,

          onTap: (tapPosition, latlng) {
            setState(() => points.add(latlng));
          },

          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all),
        ),

        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          ),

          // Draw polygon if at least 3 points
          if (points.length >= 3)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: points,
                  color: Colors.green.withOpacity(0.3),
                  borderStrokeWidth: 3,
                  borderColor: Colors.green,
                )
              ],
            ),

          // Draw small red dots for each point
          MarkerLayer(
            markers: points
                .map(
                  (p) => Marker(
                    point: p,
                    width: 25,
                    height: 25,
                    child: const Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                )
                .toList(),
          )
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Undo last point
            ElevatedButton.icon(
              onPressed: () {
                if (points.isNotEmpty) {
                  setState(() => points.removeLast());
                }
              },
              icon: const Icon(Icons.undo),
              label: const Text("Undo"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),

            // Clear all points
            ElevatedButton.icon(
              onPressed: () => setState(() => points.clear()),
              icon: const Icon(Icons.delete),
              label: const Text("Clear"),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}
