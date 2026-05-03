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

  static const _green = Color(0xFF2E7D32);
  static const _darkGreen = Color(0xFF1B5E20);

  @override
  void initState() {
    super.initState();
    fetchFields();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          'registered_fields'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => loading = true);
              fetchFields();
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : fields.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.agriculture_outlined,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'no_fields'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchFields,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: fields.length,
                    itemBuilder: (context, i) {
                      final f = fields[i];
                      final farmerPhotoUrl = f["photo_url"] != null
                          ? "${ApiService.baseUrl}${f["photo_url"]}"
                          : null;

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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FieldDetailPage(field: f),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Farmer photo
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: farmerPhotoUrl != null
                                      ? Image.network(
                                          farmerPhotoUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _placeholderIcon(),
                                        )
                                      : _placeholderIcon(),
                                ),

                                const SizedBox(width: 14),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f["village"] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: _darkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.grass,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            f["crop"] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.phone_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            f["phone"] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
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
                  ),
                ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.person_outline,
        color: Colors.green.shade300,
        size: 32,
      ),
    );
  }
}