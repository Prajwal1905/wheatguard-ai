import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:easy_localization/easy_localization.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../utils/disease_names.dart';
import 'map_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<Map<String, dynamic>> alerts = [];
  IO.Socket? socket;
  bool _isLoading = true;

  final Map<String, String> _locationCache = {};

  @override
  void initState() {
    super.initState();
    fetchAlerts();
    _initSocket();
  }

  @override
  void dispose() {
    socket?.dispose();
    super.dispose();
  }

  Future<String> _getReadableLocation(double lat, double lon) async {
    final key = "$lat,$lon";

    if (_locationCache.containsKey(key)) {
      return _locationCache[key]!;
    }

    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality?.trim() ?? "";
        final state = p.administrativeArea?.trim() ?? "";

        final readable = city.isNotEmpty ? "$city, $state" : (state.isNotEmpty ? state : "Unknown");
        _locationCache[key] = readable;
        return readable;
      }
    } catch (e) {
      debugPrint("Location decode error: $e");
    }

    return "Unknown";
  }

  Future<void> fetchAlerts() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getAlerts();
      final list = List<Map<String, dynamic>>.from(data);

      setState(() => alerts = list);

      
      final box = Hive.box("alert_history");

      for (var a in list) {
        final id = (a["id"] ?? "").toString();

        final exists = box.values.any((m) => (m["id"]?.toString() ?? "") == id);
        if (!exists) box.add(a);
      }
    } catch (e) {
      debugPrint("Alert load error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("alerts_load_error"))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  
  void _initSocket() {
  socket = IO.io(
    "http://10.0.2.2:8000",
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
  );

  socket!.onConnect((_) => debugPrint("Alerts socket connected"));
  socket!.onDisconnect((_) => debugPrint("Alerts socket disconnected"));

  socket!.on("new_alert", (data) => _handleRealtimeAlert(data));

  socket!.connect();
}


  void _handleRealtimeAlert(dynamic a) {
    final alert = {
      "id": (a["id"] ?? "").toString(),
      "disease": a["disease"] ?? "Unknown",
      "severity": a["severity"] ?? "N/A",
      "cases": a["cases"] ?? 0,
      "lat": (a["lat"] ?? 0).toDouble(),
      "lon": (a["lon"] ?? 0).toDouble(),
      "timestamp": a["timestamp"] ?? DateTime.now().toIso8601String(),
    };

    setState(() => alerts.insert(0, alert));

   
    final box = Hive.box("alert_history");
    final exists = box.values.any((m) => (m["id"]?.toString() ?? "") == alert["id"]);
    if (!exists) box.add(alert);
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
      case "⚠️ high":
        return Colors.redAccent;
      case "moderate":
      case "medium":
      case "🟡 moderate":
        return Colors.orangeAccent;
      case "low":
      case "🟢 low":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(dynamic ts) {
    try {
      late DateTime dt;

      if (ts is String) {
        dt = DateTime.tryParse(ts) ?? DateTime.now();
      } else if (ts is DateTime) {
        dt = ts;
      } else {
        dt = DateTime.now();
      }

      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("alerts_title")),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAlerts,
          )
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? Center(child: Text(tr("alerts_empty"), style: const TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];

                    final diseaseRaw = alert["disease"] ?? "Unknown";
                    final disease = DiseaseNames.get(diseaseRaw, lang);

                    final severity = alert["severity"] ?? "N/A";
                    final cases = alert["cases"]?.toString() ?? "?";
                    final lat = (alert["lat"] ?? 0).toDouble();
                    final lon = (alert["lon"] ?? 0).toDouble();

                    final color = _severityColor(severity);

                    return FutureBuilder<String>(
                      future: _getReadableLocation(lat, lon),
                      builder: (context, snap) {
                        final location = snap.data ?? "Unknown";

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapPage(
                                    alertLat: lat,
                                    alertLon: lon,
                                    alertRadiusKm: 5,
                                  ),
                                ),
                              );
                            },

                            leading: CircleAvatar(
                              backgroundColor: color.withOpacity(0.15),
                              child: Icon(Icons.warning_amber_rounded, color: color),
                            ),

                            title: Text(
                              disease,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),

                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Chip(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      backgroundColor: color.withOpacity(0.15),
                                      label: Text(
                                        severity,
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text("${tr('alerts_cases')}: $cases", style: const TextStyle(fontSize: 12)),
                                  ],
                                ),

                                Text("📍 ${tr('alerts_location')}: $location",
                                    style: const TextStyle(fontSize: 12)),

                                Text(
                                  "${tr('alerts_time')}: ${_formatTime(alert["timestamp"] ?? alert["created_at"])}",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
