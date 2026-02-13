import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:pdf/widgets.dart' as pw ;

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
      appBar: AppBar(
        title: Text(tr('history')),
        backgroundColor: Colors.green,
        actions: [
          if (predictions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Export PDF'),
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
              child: Text(
                tr('no_history'),
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final item = predictions[index];
                final imgFile = File(item['imagePath']);
                final imageExists = imgFile.existsSync();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        
                        GestureDetector(
                          onTap: imageExists ? () => _openImagePreview(imgFile) : null,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: imageExists
                                ? Image.file(imgFile,
                                    width: 70, height: 70, fit: BoxFit.cover)
                                : const Icon(Icons.broken_image,
                                    size: 70, color: Colors.grey),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['disease'].toString().toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),

                              const SizedBox(height: 4),
                              Text("${tr('confidence')}: ${item['confidence']}%"),
                              Text("${tr('remedy')}: ${item['remedy']}"),
                              Text("🕒 ${item['timestamp']}"),

                              if (!(item['synced'] == true))
                                const Text("Not Synced",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 12)),
                            ],
                          ),
                        ),

                        
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.cloud_upload,
                                  color: Colors.blue),
                              onPressed: () => _syncToBackend(item),
                            ),
                            IconButton(
  icon: const Icon(Icons.delete, color: Colors.red),
  onPressed: () async {
    try {
      final reportId = item["report_id"] ?? 0;

      if (reportId != 0) {
        await ApiService.deleteDetection(reportId);  
      }

      
      final key = box.keys.firstWhere(
        (k) => box.get(k)['timestamp'] == item['timestamp'],
        orElse: () => null,
      );

      if (key != null) {
        box.delete(key);
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deleted Successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  },
),

                          ],
                        )
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
        title: const Text("Delete All History"),
        content: const Text("Are you sure you want to delete all items?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              box.clear();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  
  Future<void> _syncToBackend(Map item) async {
    final file = File(item["imagePath"]);

    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Image not found. Cannot sync.")),
      );
      return;
    }

    if (item['lat'] == null || item['lon'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Missing location data.")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⏳ Uploading image...")),
    );

    final imageUrl = await ApiService.uploadImage(file);
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Image upload failed!")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⏳ Syncing...")),
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
        const SnackBar(content: Text(" Synced successfully!"), backgroundColor: Colors.green),
      );

      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Sync failed"), backgroundColor: Colors.red),
      );
    }
  }

  /// PDF ==========================
  Future<void> _generateAndSharePDF(List<Map> predictions) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
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
                p['timestamp']
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              font: font,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green600),
            cellStyle: pw.TextStyle(font: font, fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Wheat_Report_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: "Wheat Disease Report");
  }
}
