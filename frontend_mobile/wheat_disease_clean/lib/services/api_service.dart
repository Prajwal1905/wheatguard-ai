import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  // Token management
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Returns headers with Authorization if a token is stored.
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Disease detection
  static Future<Map<String, dynamic>> predictDisease(
    File imageFile,
    String language,
    double lat,
    double lon,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/detections/predict'),
    );

    final deviceId = await getDeviceId();

    request.fields['language']  = language;
    request.fields['lat']       = lat.toString();
    request.fields['lon']       = lon.toString();
    request.fields['device_id'] = deviceId;
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      return jsonDecode(res.body);
    } else {
      throw Exception('Prediction failed: ${response.statusCode}');
    }
  }

  // Save detection
  static Future<void> saveDetection(Map<String, dynamic> data) async {
    final headers = await authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/detections/save'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to save detection: ${response.statusCode}');
    }
  }

  // Map data
  static Future<List<dynamic>> getMapData() async {
    final headers = await authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/detections/map_data'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data as List).where((d) =>
        d['lat'] != null && d['lon'] != null
      ).toList();
    } else {
      throw Exception('Failed to load map data: ${response.statusCode}');
    }
  }

  // Alerts
  static Future<List<Map<String, dynamic>>> getAlerts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/alerts/nearby?lat=0&lon=0'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      throw Exception('Unexpected alerts format');
    } else {
      throw Exception('Failed to load alerts: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> getNearbyAlerts(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/alerts/nearby?lat=$lat&lon=$lon'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch nearby alerts');
    }
  }

  /// Chatbot is open — no token needed
  static Future<String> askChatbot(
    String disease,
    String question,
    String language,
  ) async {
    final body = {
      'disease':  disease,   // fixed: backend ChatRequest expects "disease"
      'question': question,
      'language': language,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/ai/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['reply'] ?? 'No reply';
    } else {
      return 'AI is unavailable right now. Please try again.';
    }
  }

  // Offline sync — open
  static Future<bool> syncLocalDetection(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sync/local-detection'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Sync error: $e');
      return false;
    }
  }

  // Image upload
  static Future<String?> uploadImage(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload/image'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final response = await request.send();
    final body     = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return jsonDecode(body)['url'];
    }
    print('Upload failed ${response.statusCode}: $body');
    return null;
  }

  // Delete detection
  static Future<void> deleteDetection(int reportId) async {
    final deviceId = await getDeviceId();
    final response = await http.delete(
      Uri.parse('$baseUrl/detections/$reportId?device_id=$deviceId'),
    );
    if (response.statusCode == 403) {
      throw Exception('You can only delete detections from your own device.');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to delete: ${response.statusCode}');
    }
  }

  // FCM
  static Future<String> getDeviceId() async {
    final info    = DeviceInfoPlugin();
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
      'device_id': deviceId,
      'token':     token,
      'lat':       lat,
      'lon':       lon,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/fcm/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }
}