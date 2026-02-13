import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

import '../services/api_service.dart';
import 'field_detail_page.dart';

class FieldListPage extends StatefulWidget {
  const FieldListPage({super.key});

  @override
  State<FieldListPage> createState() => _FieldListPageState();
}

class _FieldListPageState extends State<FieldListPage> {
  List<dynamic> fields = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchFields();
  }

  // ---------------- FETCH FIELDS ----------------
  Future<void> fetchFields() async {
    try {
      final url = Uri.parse("${ApiService.baseUrl}/fields/");
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          fields = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('registered_fields'.tr()),
        backgroundColor: Colors.green.shade700,
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fields.isEmpty
              ? Center(child: Text('no_fields'.tr()))
              : RefreshIndicator(
                  onRefresh: fetchFields,
                  child: ListView.builder(
                    itemCount: fields.length,
                    itemBuilder: (context, i) {
                      final f = fields[i];

                      final farmerPhotoUrl = f["photo_url"] != null
                          ? "${ApiService.baseUrl}${f["photo_url"]}"
                          : null;

                      final fieldPhotoUrl = f["field_photo_url"] != null
                          ? "${ApiService.baseUrl}${f["field_photo_url"]}"
                          : null;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: ListTile(
                          leading: SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: farmerPhotoUrl == null
                                      ? const Icon(Icons.person, size: 40)
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            farmerPhotoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.broken_image),
                                          ),
                                        ),
                                ),
                                if (fieldPhotoUrl != null)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.landscape, size: 16, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          title: Text(
                            "${f["village"] ?? 'unknown'.tr()} — ${f["crop"] ?? ''}",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),

                          subtitle: Text("${'phone'.tr()}: ${f["phone"] ?? "-"}"),

                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),

                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FieldDetailPage(field: f),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
