import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _fln = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _fln.initialize(initSettings);

    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } else {
      await _fln
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    final fm = FirebaseMessaging.instance;

    final token = await fm.getToken();
    debugPrint('FCM TOKEN: $token');
    if (token != null) {
      await _sendTokenToBackend(token);
    }

    FirebaseMessaging.onMessage.listen((m) async {
      final n = m.notification;
      if (n != null) {
        await _fln.show(
          0,
          n.title,
          n.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default',
              'default',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    });

    fm.onTokenRefresh.listen((t) async => _sendTokenToBackend(t));
  }

  Future<void> _sendTokenToBackend(String token) async {
    final base = dotenv.env['API_BASE_URL'] ?? '';
    if (base.isEmpty) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final stored = sp.getString('fcm_token');
      if (stored == token) return;

      final dio = Dio(
        BaseOptions(baseUrl: base, headers: {'Accept': 'application/json'}),
      );
      await dio.post(
        '/v1/devices',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );

      await sp.setString('fcm_token', token);
    } catch (_) {}
  }
}
