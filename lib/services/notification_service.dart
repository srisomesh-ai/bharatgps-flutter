import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Bundled alert sounds. Each one becomes its own Android notification channel,
/// because Android locks a channel's sound at creation time.
/// The `file` is the raw resource name (without extension) placed in
/// android/app/src/main/res/raw/<file>.mp3
class AlertSound {
  final String id;
  final String label;
  final String file; // raw resource name, or 'default'
  const AlertSound(this.id, this.label, this.file);
}

const kAlertSounds = <AlertSound>[
  AlertSound('default', 'Default', 'default'),
  AlertSound('siren', 'Siren', 'siren'),
  AlertSound('horn', 'Truck Horn', 'horn'),
  AlertSound('chime', 'Gentle Chime', 'chime'),
  AlertSound('alarm', 'Alarm Bell', 'alarm'),
  AlertSound('beep', 'Short Beep', 'beep'),
];

class NotificationService {
  static final _fln = FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  static const _prefKey = 'bgps_alert_sound';

  /// The sound the user picked (defaults to 'default').
  static Future<AlertSound> currentSound() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_prefKey) ?? 'default';
    return kAlertSounds.firstWhere((s) => s.id == id, orElse: () => kAlertSounds.first);
  }

  static Future<void> setSound(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, id);
    // ensure the channel for this sound exists
    final s = kAlertSounds.firstWhere((e) => e.id == id, orElse: () => kAlertSounds.first);
    await _ensureChannel(s);
  }

  /// Call once at app start (after Firebase.initializeApp).
  static Future<void> init() async {
    // local notifications init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // create a channel for every bundled sound up-front
    for (final s in kAlertSounds) {
      await _ensureChannel(s);
    }

    // request permission (Android 13+)
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    // token
    _fcmToken = await FirebaseMessaging.instance.getToken();
    if (_fcmToken != null) registerToken(_fcmToken!);
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _fcmToken = t;
      registerToken(t);
    });

    // foreground messages -> show a local notification with the chosen sound
    FirebaseMessaging.onMessage.listen(_showFromMessage);
  }

  static AndroidNotificationChannel _channelFor(AlertSound s) {
    return AndroidNotificationChannel(
      'bgps_alerts_${s.id}',
      'Alerts — ${s.label}',
      description: 'BharatGPS vehicle alerts (${s.label})',
      importance: Importance.high,
      playSound: true,
      sound: s.file == 'default' ? null : RawResourceAndroidNotificationSound(s.file),
    );
  }

  static Future<void> _ensureChannel(AlertSound s) async {
    final android = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channelFor(s));
  }

  static Future<void> _showFromMessage(RemoteMessage m) async {
    final sound = await currentSound();
    final n = m.notification;
    final title = n?.title ?? m.data['title'] ?? 'BharatGPS Alert';
    final body = n?.body ?? m.data['body'] ?? '';
    final details = AndroidNotificationDetails(
      'bgps_alerts_${sound.id}',
      'Alerts — ${sound.label}',
      channelDescription: 'BharatGPS vehicle alerts',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: sound.file == 'default' ? null : RawResourceAndroidNotificationSound(sound.file),
      icon: '@mipmap/ic_launcher',
    );
    await _fln.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: details),
    );
  }

  /// Preview a sound immediately (used by the settings screen play button).
  static Future<void> preview(AlertSound s) async {
    await _ensureChannel(s);
    final details = AndroidNotificationDetails(
      'bgps_alerts_${s.id}',
      'Alerts — ${s.label}',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: s.file == 'default' ? null : RawResourceAndroidNotificationSound(s.file),
      icon: '@mipmap/ic_launcher',
    );
    await _fln.show(99999, 'Sound preview', '${s.label} alert tone', NotificationDetails(android: details));
  }

  /// Send the FCM token + chosen sound to the backend relay so it can push to this device.
  static Future<void> registerToken(String token) async {
    if (!ApiService.isLoggedIn) return;
    final sound = await currentSound();
    try {
      await http.post(
        Uri.https(ApiService.host!, '/push/register_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_api_hash': ApiService.hash,
          'token': token,
          'sound': sound.id,
          'platform': 'android',
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // backend may not be deployed yet; ignore silently
    }
  }
}

/// Top-level background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Background/terminated messages with a `notification` payload are shown by
  // the system automatically using the channel specified in `android.channelId`.
  // No action needed here for display.
}
