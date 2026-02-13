import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FieldMapPage extends StatelessWidget {
  final List<LatLng> polygon;
  final LatLng center;
  final int fieldId;

  const FieldMapPage({
    super.key,
    required this.polygon,
    required this.center,
    required this.fieldId,
  });

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints(polygon);

    return Scaffold(
      appBar: AppBar(
        title: Text("Field #$fieldId Map"),
        backgroundColor: Colors.green,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 16,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          maxZoom: 19,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.wheat_disease_clean',
            additionalOptions: const {
              'User-Agent': 'WheatGuardAI Student Project',
            },
          ),

          PolygonLayer(
            polygons: [
              Polygon(
                points: polygon,
                borderStrokeWidth: 3,
                borderColor: Colors.green,
                color: Colors.green.withOpacity(0.2),
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
