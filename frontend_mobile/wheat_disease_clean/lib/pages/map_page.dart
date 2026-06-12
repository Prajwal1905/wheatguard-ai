import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/api_service.dart';
import '../utils/disease_names.dart';

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

  List<dynamic> _allDetections = [];
  String _severityFilter       = 'All';
  bool _loading                = true;
  bool _refreshing             = false;

  LatLng _initialCenter = const LatLng(20.5937, 78.9629);
  double _initialZoom   = 5.0;

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    final lat = widget.focusLat ?? widget.alertLat;
    final lon = widget.focusLon ?? widget.alertLon;
    if (lat != null && lon != null) {
      _initialCenter = LatLng(lat, lon);
      _initialZoom   = 15;
    }
    _fetchMapData();
  }

  Future<void> _fetchMapData({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() => _refreshing = true);
    }

    try {
      final headers = await ApiService.authHeaders();
      final url     = Uri.parse('${ApiService.baseUrl}/detections/map_data');
      final res     = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _allDetections = data
                .where((d) => d['lat'] != null && d['lon'] != null)
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Map data fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading    = false;
          _refreshing = false;
        });
      }
    }
  }

  List<dynamic> get _filtered {
    if (_severityFilter == 'All') return _allDetections;
    return _allDetections.where((d) {
      final sev = (d['severity'] ?? '').toString().toLowerCase();
      return sev == _severityFilter.toLowerCase();
    }).toList();
  }

  Future<void> _locateMe() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showSnack('GPS is turned off');
      return;
    }
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnack('Location permission denied');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _markerColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'critical':
        return Colors.red.shade700;
      case 'moderate':
      case 'medium':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade600;
    }
  }

  void _showDetectionDetail(dynamic d) {
    final color = _markerColor(d['severity'] ?? 'low');
    final lang  = context.locale.languageCode;

    final rawDisease     = d['disease']?.toString() ?? 'Unknown';
    final translatedName = DiseaseNames.get(rawDisease, lang);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Disease name + severity
            Row(
              children: [
                Expanded(
                  child: Text(
                    translatedName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    _translateSeverity(d['severity'] ?? 'low'),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Detail rows
            _detailRow(Icons.percent, tr('confidence'),
                '${d['confidence'] ?? '-'}%'),
            _detailRow(Icons.gps_fixed, tr('map_coordinates'),
                '${(d['lat'] as num).toStringAsFixed(4)}, '
                '${(d['lon'] as num).toStringAsFixed(4)}'),
            if (d['timestamp'] != null)
              _detailRow(Icons.access_time, tr('map_detected'),
                  _formatTimestamp(d['timestamp'])),
            if (d['source'] != null)
              _detailRow(Icons.sensors, tr('map_source'),
                  _translateSource(d['source'])),

            const SizedBox(height: 16),

            // Confidence bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (double.tryParse(
                            d['confidence']?.toString() ?? '0') ??
                        0) /
                    100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString());
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}, '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  String _monthName(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _translateSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'critical':
        return tr('severity_high');
      case 'moderate':
      case 'medium':
        return tr('severity_moderate');
      case 'low':
        return tr('severity_low');
      default:
        return severity;
    }
  }

  String _translateSource(String source) {
    switch (source.toLowerCase()) {
      case 'mobile':
        return tr('source_mobile');
      case 'drone':
        return tr('source_drone');
      case 'manual':
        return tr('source_manual');
      default:
        return _capitalise(source);
    }
  }

  List<Marker> _buildMarkers() {
    return _filtered.map((d) {
      final color = _markerColor(d['severity'] ?? 'low');
      return Marker(
        width: 44,
        height: 44,
        point: LatLng(
            (d['lat'] as num).toDouble(),
            (d['lon'] as num).toDouble()),
        child: GestureDetector(
          onTap: () => _showDetectionDetail(d),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
              ),
              Icon(Icons.location_on, color: color, size: 22),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text(
          'Disease Map',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _fetchMapData(isRefresh: true),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _locateMe,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Map
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

                // Severity filter bar
                Positioned(
                  top: 12,
                  left: 12,
                  right: 72,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'High', 'Moderate', 'Low']
                          .map((sev) => _filterPill(sev))
                          .toList(),
                    ),
                  ),
                ),

                // Detection count + empty state
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: filtered.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.1),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              _severityFilter == 'All'
                                  ? 'No detections yet'
                                  : 'No $_severityFilter detections',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withOpacity(0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  '${filtered.length} detection'
                                  '${filtered.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_severityFilter != 'All') ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '· $_severityFilter',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _filterPill(String label) {
    final isActive = _severityFilter == label;
    Color pillColor;
    switch (label) {
      case 'High':
        pillColor = Colors.red.shade700;
        break;
      case 'Moderate':
        pillColor = Colors.orange.shade700;
        break;
      case 'Low':
        pillColor = Colors.green.shade600;
        break;
      default:
        pillColor = _green;
    }

    return GestureDetector(
      onTap: () => setState(() => _severityFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? pillColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? pillColor : Colors.grey.shade300,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}