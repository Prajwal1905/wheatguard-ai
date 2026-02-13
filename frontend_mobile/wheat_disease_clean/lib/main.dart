import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/map_page.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  NotificationService.showOutbreakAlert(
    title: message.notification?.title ?? "New Alert",
    body: message.notification?.body ?? "Tap to open",
    lat: double.tryParse(message.data["lat"] ?? "0") ?? 0.0,
    lon: double.tryParse(message.data["lon"] ?? "0") ?? 0.0,
    disease: message.data["disease"] ?? "Unknown",
  );
}

Future<Map<String, double>> _getUserLocation() async {
  LocationPermission p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) {
    p = await Geolocator.requestPermission();
  }

  final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);

  return {
    "lat": pos.latitude,
    "lon": pos.longitude,
  };
}

Future<String> getDeviceId() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    var info = await deviceInfo.androidInfo;
    return info.id; 
  } else if (Platform.isIOS) {
    var info = await deviceInfo.iosInfo;
    return info.identifierForVendor ?? "ios-device";
  }

  return "unknown-device";
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.requestPermissions();
  await NotificationService.init();

  await Hive.initFlutter();
  await Hive.openBox('predictions');
  await Hive.openBox('alert_history');

  
  try {
    final token = await FirebaseMessaging.instance.getToken();
    final loc = await _getUserLocation();

    if (token != null) {
      final deviceId = await getDeviceId();

      await ApiService.registerFcmToken(
        deviceId: deviceId,
        token: token,
        lat: loc["lat"]!,
        lon: loc["lon"]!,
      );

      print(" FCM Registered to Backend");
    }
  } catch (e) {
    print(" FCM registration failed: $e");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );

  
  NotificationService.onNotificationTap.listen((data) {
    if (navigatorKey.currentState == null) return;

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => MapPage(
          alertLat: data["lat"] ?? 0,
          alertLon: data["lon"] ?? 0,
          alertRadiusKm: 5,
          diseaseName: data["disease"] ?? "Unknown",
        ),
      ),
    );
  });
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'WheatGuard AI',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
