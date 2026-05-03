import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:easy_localization/easy_localization.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../utils/disease_names.dart';
import 'map_page.dart';
import '../config.dart';

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
    if (_locationCache.containsKey(key)) return _locationCache[key]!;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = p.locality?.trim() ?? "";
        final state = p.administrativeArea?.trim() ?? "";
        final readable = city.isNotEmpty
            ? "$city, $state"
            : (state.isNotEmpty ? state : "Unknown");
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
        final exists =
            box.values.any((m) => (m["id"]?.toString() ?? "") == id);
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
      AppConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    socket!.onConnect((_) => debugPrint("Socket connected"));
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
    final exists =
        box.values.any((m) => (m["id"]?.toString() ?? "") == alert["id"]);
    if (!exists) box.add(alert);
  }

  Color _severityColor(String s) {
    s = s.toLowerCase();
    if (s.contains("high")) return Colors.red.shade700;
    if (s.contains("moderate") || s.contains("medium"))
      return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  IconData _severityIcon(String s) {
    s = s.toLowerCase();
    if (s.contains("high")) return Icons.warning_rounded;
    if (s.contains("moderate")) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  String _formatTime(dynamic ts) {
    try {
      final dt = ts is String
          ? (DateTime.tryParse(ts) ?? DateTime.now())
          : DateTime.now();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        title: Text(
          tr("alerts_title"),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchAlerts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr("alerts_empty"),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
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
                        final location = snap.data ?? "...";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: color.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MapPage(
                                  alertLat: lat,
                                  alertLon: lon,
                                  alertRadiusKm: 5,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _severityIcon(severity),
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          disease,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    color.withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                severity,
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "${tr('alerts_cases')}: $cases",
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "📍 $location",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _formatTime(
                                            alert["timestamp"] ??
                                                alert["created_at"],
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
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