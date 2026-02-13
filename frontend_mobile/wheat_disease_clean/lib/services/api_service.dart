import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class ApiService {
  
  //static const String baseUrl = "http://10.239.104.35:8000";
  //static String baseUrl = "http://127.0.0.1:8000";
  static const String baseUrl = "http://172.31.107.35:8000";

  
  static Future<Map<String, dynamic>> predictDisease(
    File imageFile,
    String language,
    double lat,
    double lon,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/detections/predict'),
    );

    request.fields['language'] = language;
    request.fields['lat'] = lat.toString();
    request.fields['lon'] = lon.toString();

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
    ));

    var response = await request.send();

    if (response.statusCode == 200) {
      var res = await http.Response.fromStream(response);
      return jsonDecode(res.body);
    } else {
      throw Exception("Prediction failed: ${response.statusCode}");
    }
  }

  static Future<void> saveDetection(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/detections/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save detection: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getMapData() async {
    final response = await http.get(Uri.parse('$baseUrl/detections/map_data'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data.where((d) => d['lat'] != null && d['lon'] != null).toList();
    } else {
      throw Exception("Failed to load map data");
    }
  }

  static Future<List<Map<String, dynamic>>> getAlerts() async {
    final response = await http.get(Uri.parse('$baseUrl/alerts/'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data is List) {
        return data
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      } else {
        throw Exception("Unexpected alerts format");
      }
    } else {
      throw Exception("Failed to load alerts: ${response.statusCode}");
    }
  }

  static Future<List<dynamic>> getNearbyAlerts(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/map/nearby?lat=$lat&lon=$lon'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception("Failed to fetch nearby alerts");
    }
  }

  static Future<String> askChatbot(
    String disease,
    String question,
    String language,
  ) async {
    final body = {
      "disease": disease,
      "question": question,
      "language": language,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['reply'] ?? "No reply";
    } else {
      return "AI unable to reply.";
    }
  }

  static Future<bool> syncLocalDetection(Map data) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/sync/local-detection"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      return res.statusCode == 200;
    } catch (e) {
      print("Sync error: $e");
      return false;
    }
  }

  static Future<String?> uploadImage(File file) async {
    final req = http.MultipartRequest(
      "POST",
      Uri.parse("$baseUrl/upload/image"),
    );

    req.files.add(await http.MultipartFile.fromPath("file", file.path));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      final data = jsonDecode(body);
      return data["url"];
    } else {
      print("Upload failed ${res.statusCode}");
      print("Response: $body");
      return null;
    }
  }

  static Future<void> deleteDetection(int reportId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/detections/$reportId"),
    );

    if (res.statusCode != 200) {
      throw Exception("Failed to delete: ${res.statusCode}");
    }
  }

  static Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id;
  }

  static Future<bool> registerFcmToken({
    required String deviceId,
    required String token,
    required double lat,
    required double lon,
  }) async {
    final body = {
      "device_id": deviceId,
      "token": token,
      "lat": lat,
      "lon": lon,
    };

    final res = await http.post(
      Uri.parse("$baseUrl/fcm/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return res.statusCode == 200;
  }
}

