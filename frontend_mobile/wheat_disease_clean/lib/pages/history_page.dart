import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Box box = Hive.box('predictions');

  // Filters
  String _filterDisease  = 'All';
  String _filterSync     = 'All';   // All | Synced | Not Synced
  String _filterSeverity = 'All';
  String _searchQuery    = '';

  static const _green     = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _startConnectivityListener();
  }

  List<Map> _allPredictions() {
    final items = box.values.cast<Map>().toList();
    items.sort((a, b) =>
        (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
    return items;
  }

  List<Map> _filtered() {
    return _allPredictions().where((item) {
      final disease  = (item['disease'] ?? '').toString().toLowerCase();
      final severity = (item['severity'] ?? '').toString().toLowerCase();
      final synced   = item['synced'] == true;

      final matchSearch = _searchQuery.isEmpty ||
          disease.contains(_searchQuery.toLowerCase());

      final matchDisease = _filterDisease == 'All' ||
          (item['disease'] ?? '') == _filterDisease;

      final matchSync = _filterSync == 'All' ||
          (_filterSync == 'Synced' && synced) ||
          (_filterSync == 'Not Synced' && !synced);

      final matchSeverity = _filterSeverity == 'All' ||
          severity == _filterSeverity.toLowerCase();

      return matchSearch && matchDisease && matchSync && matchSeverity;
    }).toList();
  }

  List<String> _uniqueDiseases() {
    final diseases = _allPredictions()
        .map((i) => (i['disease'] ?? '').toString())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    diseases.sort();
    return ['All', ...diseases];
  }

  int get _activeFilterCount {
    int count = 0;
    if (_filterDisease != 'All')  count++;
    if (_filterSync != 'All')     count++;
    if (_filterSeverity != 'All') count++;
    if (_searchQuery.isNotEmpty)  count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _filterDisease  = 'All';
      _filterSync     = 'All';
      _filterSeverity = 'All';
      _searchQuery    = '';
    });
  }

  void _startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        for (var item in box.values) {
          if (item['synced'] == false) {
            await _syncToBackend(Map.from(item));
          }
        }
        if (mounted) setState(() {});
      }
    });
  }

  Color _severityColor(String sev) {
    sev = sev.toLowerCase();
    if (sev.contains('high'))                          return Colors.red.shade700;
    if (sev.contains('moderate') || sev.contains('medium')) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  Color _confidenceColor(double conf) {
    if (conf >= 80) return Colors.green.shade600;
    if (conf >= 60) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final predictions = _filtered();
    final all         = _allPredictions();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          tr('history'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_activeFilterCount > 0)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off,
                  color: Colors.white, size: 18),
              label: Text(
                'Clear ($_activeFilterCount)',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          if (all.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _confirmDeleteAll,
              tooltip: 'Delete All',
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text(
          'Export PDF',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (predictions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('no_history'))),
            );
            return;
          }
          _generateAndSharePDF(predictions);
        },
      ),

      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search disease…',
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () =>
                            setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _filterChip(
                  'Disease',
                  _filterDisease,
                  _uniqueDiseases(),
                  (v) => setState(() => _filterDisease = v),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Severity',
                  _filterSeverity,
                  ['All', 'High', 'Moderate', 'Low'],
                  (v) => setState(() => _filterSeverity = v),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Sync',
                  _filterSync,
                  ['All', 'Synced', 'Not Synced'],
                  (v) => setState(() => _filterSync = v),
                ),
              ],
            ),
          ),

          // Summary bar
          if (all.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${predictions.length} of ${all.length} detection${all.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  _summaryPill(
                    '${all.where((i) => i['synced'] == true).length} synced',
                    Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _summaryPill(
                    '${all.where((i) => i['synced'] != true).length} pending',
                    Colors.orange,
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: predictions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _activeFilterCount > 0
                              ? 'No results match your filters.'
                              : tr('no_history'),
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600),
                        ),
                        if (_activeFilterCount > 0) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off,
                                size: 16),
                            label: const Text('Clear filters'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                    itemCount: predictions.length,
                    itemBuilder: (context, index) {
                      final item    = predictions[index];
                      final imgFile = File(item['imagePath'] ?? '');
                      final imageExists = imgFile.existsSync();
                      final isSynced   = item['synced'] == true;
                      final confidence =
                          double.tryParse(
                                  item['confidence']?.toString() ?? '0') ??
                              0.0;
                      final disease = (item['disease'] ?? 'Unknown')
                          .toString()
                          .toUpperCase();
                      final severity =
                          item['severity']?.toString() ?? 'Low';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Image
                              GestureDetector(
                                onTap: imageExists
                                    ? () => _openImagePreview(imgFile)
                                    : null,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  child: imageExists
                                      ? Image.file(imgFile,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover)
                                      : Container(
                                          width: 72,
                                          height: 72,
                                          color: Colors.grey.shade100,
                                          child: Icon(
                                            Icons
                                                .image_not_supported_outlined,
                                            color: Colors.grey.shade400,
                                            size: 30,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    // Disease + severity
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            disease,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: _darkGreen,
                                            ),
                                          ),
                                        ),
                                        _severityBadge(severity),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    // Confidence bar
                                    Row(
                                      children: [
                                        Text(
                                          '${confidence.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _confidenceColor(
                                                confidence),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child:
                                                LinearProgressIndicator(
                                              value: confidence / 100,
                                              minHeight: 6,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                _confidenceColor(
                                                    confidence),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      item['timestamp'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),

                                    const SizedBox(height: 5),

                                    // Sync badge
                                    _syncBadge(isSynced),
                                  ],
                                ),
                              ),

                              // Actions
                              Column(
                                children: [
                                  if (!isSynced)
                                    IconButton(
                                      icon: const Icon(
                                          Icons.cloud_upload_outlined,
                                          color: Colors.blue,
                                          size: 22),
                                      onPressed: () =>
                                          _syncToBackend(
                                              Map.from(item)),
                                      tooltip: 'Sync',
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.red.shade400,
                                        size: 22),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _deleteItem(item),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _severityBadge(String severity) {
    final color = _severityColor(severity);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        severity,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }

  Widget _syncBadge(bool synced) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: synced
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: synced
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            synced ? Icons.cloud_done : Icons.cloud_off,
            size: 11,
            color: synced
                ? Colors.green.shade700
                : Colors.orange.shade700,
          ),
          const SizedBox(width: 3),
          Text(
            synced ? 'Synced' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              color: synced
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, MaterialColor color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: color.shade700,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _filterChip(
    String label,
    String current,
    List<String> options,
    Function(String) onChanged,
  ) {
    final isActive = current != 'All';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF2E7D32).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFF2E7D32)
              : Colors.grey.shade300,
        ),
      ),
      child: DropdownButton<String>(
        value: current,
        isDense: true,
        underline: const SizedBox(),
        style: TextStyle(
          fontSize: 13,
          color: isActive ? _darkGreen : Colors.black87,
          fontWeight:
              isActive ? FontWeight.bold : FontWeight.normal,
        ),
        items: options
            .map((o) =>
                DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  void _openImagePreview(File img) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.file(img)),
      ),
    );
  }

  Future<void> _deleteItem(Map item) async {
    try {
      final reportId = item['report_id'] ?? 0;
      if (reportId != 0) {
        await ApiService.deleteDetection(reportId);
      }
      final key = box.keys.firstWhere(
        (k) => box.get(k)['timestamp'] == item['timestamp'],
        orElse: () => null,
      );
      if (key != null) box.delete(key);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete All History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to delete all detection history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              box.clear();
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToBackend(Map item) async {
    final file = File(item['imagePath'] ?? '');
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image not found. Cannot sync.')),
        );
      }
      return;
    }

    if (item['lat'] == null || item['lon'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Missing location data.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading…')),
      );
    }

    final imageUrl = await ApiService.uploadImage(file);
    if (imageUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image upload failed.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    final ok = await ApiService.syncLocalDetection({
      'disease':       item['disease'],
      'confidence':    item['confidence'],
      'severity':      item['severity'] ?? 'Low',
      'lat':           item['lat'],
      'lon':           item['lon'],
      'image_url':     imageUrl,
      'model_version': item['model_version'] ??
          '19-class-efficientnet-b3-onnx',
    });

    if (ok) {
      final key = box.keys.firstWhere(
        (k) => box.get(k)['timestamp'] == item['timestamp'],
        orElse: () => null,
      );
      if (key != null) {
        final updated = Map.of(item);
        updated['synced'] = true;
        await box.put(key, updated);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Synced successfully'),
              backgroundColor: Colors.green),
        );
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sync failed. Try again.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateAndSharePDF(List<Map> predictions) async {
    final font = pw.Font.ttf(
      await rootBundle
          .load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'WheatGuard — Detection Report',
              style: pw.TextStyle(
                font: font,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'Generated: ${DateTime.now().toString().substring(0, 16)}',
              style: pw.TextStyle(font: font, fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'Disease',
              'Confidence',
              'Severity',
              'Date/Time',
              'Synced',
            ],
            data: predictions.map((p) {
              return [
                p['disease'] ?? '-',
                '${p['confidence'] ?? 0}%',
                p['severity'] ?? '-',
                p['timestamp'] ?? '-',
                p['synced'] == true ? 'Yes' : 'No',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle:
                pw.TextStyle(font: font, fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir  = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/WheatGuard_Report_'
      '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'WheatGuard Detection Report',
    );
  }
}
