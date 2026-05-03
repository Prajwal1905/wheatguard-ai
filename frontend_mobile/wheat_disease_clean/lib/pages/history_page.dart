import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Box box = Hive.box('predictions');

  static const _green = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    _startConnectivityListener();
  }

  List<Map> getFilteredPredictions() {
    final List<Map> items = box.values.cast<Map>().toList();
    items.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    return items;
  }

  void _startConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        for (var item in box.values) {
          if (item['synced'] == false) {
            await _syncToBackend(item);
          }
        }
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final predictions = getFilteredPredictions();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          tr('history'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (predictions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _confirmDeleteAll,
              tooltip: "Delete All",
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade700,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text(
          'Export PDF',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

      body: predictions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 72,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr('no_history'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final item = predictions[index];
                final imgFile = File(item['imagePath'] ?? '');
                final imageExists = imgFile.existsSync();
                final isSynced = item['synced'] == true;
                final confidence = item['confidence']?.toString() ?? '0';
                final disease =
                    item['disease']?.toString().toUpperCase() ?? 'UNKNOWN';

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Image
                        GestureDetector(
                          onTap: imageExists
                              ? () => _openImagePreview(imgFile)
                              : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: imageExists
                                ? Image.file(
                                    imgFile,
                                    width: 75,
                                    height: 75,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 75,
                                    height: 75,
                                    color: Colors.grey.shade100,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey.shade400,
                                      size: 32,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                disease,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: _darkGreen,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Confidence bar
                              Row(
                                children: [
                                  Text(
                                    "${tr('confidence')}: ",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    "$confidence%",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              Text(
                                "🕒 ${item['timestamp']}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Sync status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSynced
                                      ? Colors.green.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSynced
                                        ? Colors.green.shade200
                                        : Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  isSynced ? "Synced" : "Not Synced",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSynced
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.cloud_upload_outlined,
                                color: Colors.blue,
                                size: 22,
                              ),
                              onPressed: () => _syncToBackend(item),
                              tooltip: "Sync",
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                                size: 22,
                              ),
                              tooltip: "Delete",
                              onPressed: () async {
                                try {
                                  final reportId = item["report_id"] ?? 0;
                                  if (reportId != 0) {
                                    await ApiService.deleteDetection(
                                      reportId,
                                    );
                                  }
                                  final key = box.keys.firstWhere(
                                    (k) =>
                                        box.get(k)['timestamp'] ==
                                        item['timestamp'],
                                    orElse: () => null,
                                  );
                                  if (key != null) box.delete(key);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Deleted Successfully"),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: $e"),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          "Delete All History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to delete all detection history?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToBackend(Map item) async {
    final file = File(item["imagePath"]);

    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image not found. Cannot sync.")),
      );
      return;
    }

    if (item['lat'] == null || item['lon'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing location data.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading image...")),
    );

    final imageUrl = await ApiService.uploadImage(file);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image upload failed!")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Syncing...")),
    );

    final ok = await ApiService.syncLocalDetection({
      "disease": item["disease"],
      "confidence": item["confidence"],
      "severity": "Medium",
      "lat": item["lat"],
      "lon": item["lon"],
      "image_url": imageUrl,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Synced successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sync failed"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _generateAndSharePDF(List<Map> predictions) async {
    final font = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/NotoSansDevanagari-Regular.ttf',
      ),
    );

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Wheat Disease Report',
              style: pw.TextStyle(
                font: font,
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Disease', 'Confidence', 'Remedy', 'Date/Time'],
            data: predictions.map((p) {
              return [
                p['disease'],
                "${p['confidence']}%",
                p['remedy'],
                p['timestamp'],
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green600,
            ),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      "${dir.path}/Wheat_Report_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Wheat Disease Report",
    );
  }
}