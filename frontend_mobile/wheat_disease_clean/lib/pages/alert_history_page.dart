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
    if (s.contains("high")) return Colors.redAccent;
    if (s.contains("moderate") || s.contains("medium")) {
      return Colors.orangeAccent;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    
    final filtered = alerts.where((a) {
      final raw = a['disease']?.toString() ?? "";
      final disease = DiseaseNames.get(raw, lang).toLowerCase();

      final severity = a['severity']?.toString().toLowerCase() ?? "";

      final dt =
          DateTime.tryParse(a['timestamp'] ?? "") ?? DateTime.now();

      final matchSearch =
          searchQuery.isEmpty || disease.contains(searchQuery.toLowerCase());

      final matchSeverity = selectedSeverity == "All"
          ? true
          : severity.contains(selectedSeverity.toLowerCase());

      final matchDisease =
          selectedDisease == "All"
              ? true
              : raw.toLowerCase() == selectedDisease.toLowerCase();

      return matchSearch && matchSeverity && matchDisease && _matchesTime(dt);
    }).toList();

    
    Map<String, List<Map>> grouped = {};
    for (var a in filtered) {
      final dt =
          DateTime.tryParse(a["timestamp"] ?? "") ?? DateTime.now();
      final label = _groupLabel(dt);

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(a);
    }

    
    final diseaseList = {
      "All",
      ...alerts.map((a) => (a['disease'] ?? '').toString()).toSet()
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr("alert_history_title")),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: () async {
                final box = Hive.box("alert_history");
                await box.clear();
                setState(() => alerts = []);
              })
        ],
      ),

      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: tr("search_disease"),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

          
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 12,
              children: [
                DropdownButton<String>(
                  value: selectedSeverity,
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All Severities")),
                    DropdownMenuItem(value: "Low", child: Text("Low")),
                    DropdownMenuItem(value: "Moderate", child: Text("Moderate")),
                    DropdownMenuItem(value: "High", child: Text("High")),
                  ],
                  onChanged: (v) => setState(() => selectedSeverity = v!),
                ),

                DropdownButton<String>(
                  value: selectedDisease,
                  items: diseaseList
                      .map((d) => DropdownMenuItem<String>(
                          value: d, child: Text(DiseaseNames.get(d, lang))))
                      .toList(),
                  onChanged: (v) => setState(() => selectedDisease = v!),
                ),

                DropdownButton<String>(
                  value: selectedTime,
                  items: const [
                    DropdownMenuItem(value: "All Time", child: Text("All Time")),
                    DropdownMenuItem(value: "Last 24 Hours", child: Text("Last 24 Hours")),
                    DropdownMenuItem(value: "Last 7 Days", child: Text("Last 7 Days")),
                    DropdownMenuItem(value: "Last 30 Days", child: Text("Last 30 Days")),
                  ],
                  onChanged: (v) => setState(() => selectedTime = v!),
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      tr("no_alerts_found"),
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  )
                : ListView(
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // DATE LABEL
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
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

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
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
                                                )));
                                  },
                                  leading: Icon(Icons.warning_amber_rounded,
                                      color: color, size: 32),
                                  title: Text(
                                    disease,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  subtitle: Text(
                                      "$sev • ${a['cases']} cases • ${DateFormat('hh:mm a').format(dt)}"),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                                ),
                              ),
                            );
                          })
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
