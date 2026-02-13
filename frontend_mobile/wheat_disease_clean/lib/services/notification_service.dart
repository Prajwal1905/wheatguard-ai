import 'dart:io';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static final StreamController<Map<String, dynamic>> _tapStream =
      StreamController.broadcast();
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _tapStream.stream;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'wheatguard_alerts',
    'WheatGuard Alerts',
    description: 'Nearby disease outbreak alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool _initialized = false;

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload != null) {
          final parts = resp.payload!.split("|");
          if (parts.length == 3) {
            final map = {
              "lat": double.tryParse(parts[0]) ?? 0.0,
              "lon": double.tryParse(parts[1]) ?? 0.0,
              "disease": parts[2],
            };
            _tapStream.add(map);
          }
        }
      },
    );

    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
      _channel,
    );

    _initialized = true;
  }

  static Future<void> showOutbreakAlert({
    required String title,
    required String body,
    required double lat,
    required double lon,
    required String disease,
  }) async {
    final payload = "$lat|$lon|$disease";

    const androidDetails = AndroidNotificationDetails(
      'wheatguard_alerts',
      'WheatGuard Alerts',
      channelDescription: 'Nearby disease outbreak alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
