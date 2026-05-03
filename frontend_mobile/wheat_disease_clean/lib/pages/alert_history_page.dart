import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/disease_names.dart';
import 'map_page.dart';

class AlertHistoryPage extends StatefulWidget {
  const AlertHistoryPage({super.key});

  @override
  State<AlertHistoryPage> createState() => _AlertHistoryPageState();
}

class _AlertHistoryPageState extends State<AlertHistoryPage> {
  List<Map> alerts = [];
  String searchQuery = '';
  String selectedSeverity = 'All';
  String selectedDisease = 'All';
  String selectedTime = "All Time";

  static const _orange = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final box = Hive.box("alert_history");
    final list = box.values.cast<Map>().toList();
    list.sort((a, b) =>
        (b['timestamp'] ?? "").compareTo(a['timestamp'] ?? ""));
    setState(() => alerts = list);
  }

  bool _matchesTime(DateTime dt) {
    final now = DateTime.now();
    final diffDays = now.difference(dt).inDays;
    switch (selectedTime) {
      case "Last 24 Hours":
        return now.difference(dt).inHours <= 24;
      case "Last 7 Days":
        return diffDays <= 7;
      case "Last 30 Days":
        return diffDays <= 30;
      default:
        return true;
    }
  }

  String _groupLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return DateFormat('MMM d, yyyy').format(dt);
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

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    final filtered = alerts.where((a) {
      final raw = a['disease']?.toString() ?? "";
      final disease = DiseaseNames.get(raw, lang).toLowerCase();
      final severity = a['severity']?.toString().toLowerCase() ?? "";
      final dt = DateTime.tryParse(a['timestamp'] ?? "") ?? DateTime.now();
      final matchSearch =
          searchQuery.isEmpty || disease.contains(searchQuery.toLowerCase());
      final matchSeverity = selectedSeverity == "All"
          ? true
          : severity.contains(selectedSeverity.toLowerCase());
      final matchDisease = selectedDisease == "All"
          ? true
          : raw.toLowerCase() == selectedDisease.toLowerCase();
      return matchSearch && matchSeverity && matchDisease && _matchesTime(dt);
    }).toList();

    Map<String, List<Map>> grouped = {};
    for (var a in filtered) {
      final dt = DateTime.tryParse(a["timestamp"] ?? "") ?? DateTime.now();
      final label = _groupLabel(dt);
      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(a);
    }

    final diseaseList = {
      "All",
      ...alerts.map((a) => (a['disease'] ?? '').toString()).toSet()
    }.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        title: Text(
          tr("alert_history_title"),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () async {
              final box = Hive.box("alert_history");
              await box.clear();
              setState(() => alerts = []);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: tr("search_disease"),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _filterChip("Severity", selectedSeverity, ["All", "Low", "Moderate", "High"],
                    (v) => setState(() => selectedSeverity = v)),
                const SizedBox(width: 8),
                _filterChip("Disease", selectedDisease, diseaseList,
                    (v) => setState(() => selectedDisease = v)),
                const SizedBox(width: 8),
                _filterChip("Time", selectedTime,
                    ["All Time", "Last 24 Hours", "Last 7 Days", "Last 30 Days"],
                    (v) => setState(() => selectedTime = v)),
              ],
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          tr("no_alerts_found"),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date label
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 6, left: 4),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),

                          ...entry.value.map((a) {
                            final raw = a['disease'] ?? "Unknown";
                            final disease = DiseaseNames.get(raw, lang);
                            final sev = a['severity'] ?? "N/A";
                            final color = _severityColor(sev);
                            final lat = (a['lat'] ?? 0).toDouble();
                            final lon = (a['lon'] ?? 0).toDouble();
                            final dt =
                                DateTime.tryParse(a['timestamp'] ?? "") ??
                                    DateTime.now();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: color.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _severityIcon(sev),
                                          color: color,
                                          size: 20,
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
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "$sev • ${a['cases']} cases • ${DateFormat('hh:mm a').format(dt)}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
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
                          }),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String current,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: DropdownButton<String>(
        value: current,
        isDense: true,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }
}