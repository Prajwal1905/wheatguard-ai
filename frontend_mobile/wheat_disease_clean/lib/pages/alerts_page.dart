import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:easy_localization/easy_localization.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
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
  List<Map<String, dynamic>> _alerts = [];
  IO.Socket? _socket;
  bool _isLoading  = true;
  bool _hasError   = false;

  // Geocoding cache — persists for the lifetime of this page
  // so the same lat/lon is never decoded twice
  final Map<String, String> _locationCache = {};

  // Pre-resolved location strings stored per alert id
  // so ListView rebuilds don't trigger new FutureBuilder calls
  final Map<String, String> _resolvedLocations = {};

  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _initSocket();
  }

  @override
  void dispose() {
    _socket?.off('new_alert');
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }
  Future<void> _fetchAlerts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError  = false;
    });

    try {
      final data = await ApiService.getAlerts();
      final list = List<Map<String, dynamic>>.from(data);

      // Save new alerts to Hive
      final box = Hive.box('alert_history');
      for (final a in list) {
        final id     = (a['id'] ?? '').toString();
        final exists = box.values.any(
            (m) => (m['id']?.toString() ?? '') == id);
        if (!exists) box.add(a);
      }

      if (!mounted) return;
      setState(() => _alerts = list);

      // Pre-resolve locations in the background
      _resolveAllLocations(list);
    } catch (e) {
      debugPrint('Alert load error: $e');
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Resolves all alert locations in the background after loading.
  /// Rebuilds once all are done — no per-item FutureBuilder.
  Future<void> _resolveAllLocations(
      List<Map<String, dynamic>> alerts) async {
    for (final a in alerts) {
      final id  = (a['id'] ?? '').toString();
      final lat = (a['lat'] ?? 0).toDouble();
      final lon = (a['lon'] ?? 0).toDouble();

      if (_resolvedLocations.containsKey(id)) continue;

      final location = await _getReadableLocation(lat, lon);
      if (mounted) {
        setState(() => _resolvedLocations[id] = location);
      }
    }
  }

  Future<String> _getReadableLocation(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
    if (_locationCache.containsKey(key)) return _locationCache[key]!;

    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p     = placemarks.first;
        final city  = p.locality?.trim() ?? '';
        final state = p.administrativeArea?.trim() ?? '';
        final result = city.isNotEmpty
            ? '$city, $state'
            : (state.isNotEmpty ? state : 'Unknown');
        _locationCache[key] = result;
        return result;
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    _locationCache[key] = 'Unknown location';
    return 'Unknown location';
  }

  void _initSocket() {
    _socket = IO.io(
      AppConfig.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => debugPrint('Alerts socket connected'));
    _socket!.onDisconnect(
        (_) => debugPrint('Alerts socket disconnected'));
    _socket!.on('new_alert', _handleRealtimeAlert);
    _socket!.connect();
  }

  void _handleRealtimeAlert(dynamic data) {
    final alert = <String, dynamic>{
      'id':        (data['id'] ?? '').toString(),
      'disease':   data['disease'] ?? 'Unknown',
      'severity':  data['severity'] ?? 'N/A',
      'cases':     data['cases'] ?? 0,
      'lat':       (data['lat'] ?? 0).toDouble(),
      'lon':       (data['lon'] ?? 0).toDouble(),
      'timestamp': data['timestamp'] ??
          DateTime.now().toIso8601String(),
    };

    // Save to Hive
    final box    = Hive.box('alert_history');
    final exists = box.values
        .any((m) => (m['id']?.toString() ?? '') == alert['id']);
    if (!exists) box.add(alert);

    if (mounted) {
      setState(() => _alerts.insert(0, alert));
      _resolveAllLocations([alert]);
    }
  }

  Color _severityColor(String s) {
    s = s.toLowerCase();
    if (s.contains('high') || s.contains('critical'))
      return Colors.red.shade700;
    if (s.contains('moderate') || s.contains('medium'))
      return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  IconData _severityIcon(String s) {
    s = s.toLowerCase();
    if (s.contains('high') || s.contains('critical'))
      return Icons.warning_rounded;
    if (s.contains('moderate')) return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  String _formatTime(dynamic ts) {
    try {
      final dt = ts is String
          ? (DateTime.tryParse(ts) ?? DateTime.now())
          : DateTime.now();
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return '';
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
          tr('alerts_title'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAlerts,
          ),
        ],
      ),
      body: _buildBody(lang),
    );
  }

  Widget _buildBody(String lang) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'Could not load alerts.',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _fetchAlerts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              tr('alerts_empty'),
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Text(
              'No active disease alerts in your area.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAlerts,
      color: Colors.orange.shade700,
      child: Column(
        children: [
          // Alert count bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            color: Colors.orange.shade50,
            child: Text(
              '${_alerts.length} active alert'
              '${_alerts.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert      = _alerts[index];
                final diseaseRaw = alert['disease'] ?? 'Unknown';
                final disease    = DiseaseNames.get(diseaseRaw, lang);
                final severity   = alert['severity'] ?? 'N/A';
                final cases      = alert['cases']?.toString() ?? '?';
                final lat        = (alert['lat'] ?? 0).toDouble();
                final lon        = (alert['lon'] ?? 0).toDouble();
                final color      = _severityColor(severity);
                final alertId    = (alert['id'] ?? '').toString();
                final location   =
                    _resolvedLocations[alertId] ?? '...';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: color.withOpacity(0.25)),
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
                          alertLat:      lat,
                          alertLon:      lon,
                          alertRadiusKm: 5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Severity icon
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
                                // Disease + severity badge
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        disease,
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    _severityBadge(
                                        severity, color),
                                  ],
                                ),

                                const SizedBox(height: 5),

                                // Cases
                                Text(
                                  '${tr('alerts_cases')}: $cases',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                // Location
                                Row(
                                  children: [
                                    const Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: Colors.grey),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 3),

                                // Time
                                Text(
                                  _formatTime(alert['timestamp'] ??
                                      alert['created_at']),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(Icons.chevron_right,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _severityBadge(String severity, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
