import 'dart:async';
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
  final String category; // 'Default' | 'English' | 'Hindi' | 'Telugu' | 'Other Tones'
  const AlertSound(this.id, this.label, this.file, [this.category = 'Other Tones']);
}

// Sound categories shown when creating an alert.
const kSoundCategories = <String>['Default', 'English', 'Hindi', 'Telugu', 'Other Tones'];

const kAlertSounds = <AlertSound>[
  // Default = phone's default notification sound (no file needed)
  AlertSound('default', 'Default Notification', 'default', 'Default'),

  // English voice audios
  AlertSound('en_audio1', 'Audio 1', 'en_audio1', 'English'),
  AlertSound('en_audio2', 'Audio 2', 'en_audio2', 'English'),
  AlertSound('en_audio3', 'Audio 3', 'en_audio3', 'English'),
  AlertSound('en_audio4', 'Audio 4', 'en_audio4', 'English'),
  AlertSound('en_audio5', 'Audio 5', 'en_audio5', 'English'),
  AlertSound('en_audio6', 'Audio 6', 'en_audio6', 'English'),

  // Hindi voice audios
  AlertSound('hi_audio1', 'Audio 1', 'hi_audio1', 'Hindi'),
  AlertSound('hi_audio2', 'Audio 2', 'hi_audio2', 'Hindi'),
  AlertSound('hi_audio3', 'Audio 3', 'hi_audio3', 'Hindi'),
  AlertSound('hi_audio4', 'Audio 4', 'hi_audio4', 'Hindi'),
  AlertSound('hi_audio5', 'Audio 5', 'hi_audio5', 'Hindi'),
  AlertSound('hi_audio6', 'Audio 6', 'hi_audio6', 'Hindi'),

  // Telugu voice audios
  AlertSound('te_audio1', 'Audio 1', 'te_audio1', 'Telugu'),
  AlertSound('te_audio2', 'Audio 2', 'te_audio2', 'Telugu'),
  AlertSound('te_audio3', 'Audio 3', 'te_audio3', 'Telugu'),
  AlertSound('te_audio4', 'Audio 4', 'te_audio4', 'Telugu'),
  AlertSound('te_audio5', 'Audio 5', 'te_audio5', 'Telugu'),
  AlertSound('te_audio6', 'Audio 6', 'te_audio6', 'Telugu'),

  // Other tones
  AlertSound('siren', 'Siren', 'siren', 'Other Tones'),
  AlertSound('buzzer', 'Buzzer', 'buzzer', 'Other Tones'),
  AlertSound('bell', 'Bell', 'bell', 'Other Tones'),
  AlertSound('alert', 'Alert', 'alert', 'Other Tones'),
  AlertSound('beep', 'Beep', 'beep', 'Other Tones'),
  AlertSound('horn', 'Horn', 'horn', 'Other Tones'),
];

// helper: sounds in a given category
List<AlertSound> soundsInCategory(String category) =>
    kAlertSounds.where((s) => s.category == category).toList();

class NotificationService {
  static final _fln = FlutterLocalNotificationsPlugin();
  static String? _fcmToken;
  static const _prefKey = 'bgps_alert_sound';

  /// Alert types that can each have their own sound.
  static const alertTypes = <String, String>{
    'overspeed': 'Over Speed',
    'move_duration': 'Movement',
    'engine_on': 'Engine ON',
    'engine_off': 'Engine OFF',
    'offline': 'Offline',
    'powercut': 'GPS Power Cut',
    'lowbattery': 'Low Battery',
  };

  /// Per-type sound: the sound chosen for a specific alert type.
  /// Falls back to the global sound if the user hasn't set one for that type.
  static Future<AlertSound> soundForType(String type) async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('bgps_sound_$type') ?? p.getString(_prefKey) ?? 'default';
    return kAlertSounds.firstWhere((s) => s.id == id, orElse: () => kAlertSounds.first);
  }

  static Future<void> setSoundForType(String type, String soundId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('bgps_sound_$type', soundId);
    final s = kAlertSounds.firstWhere((e) => e.id == soundId, orElse: () => kAlertSounds.first);
    await _ensureChannel(s);
  }

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
    await _initLocal();
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
    // in-app alert polling (works even without Firebase/webhook configured)
    startEventPolling();
  }

  /// Local notifications + in-app polling only (when Firebase isn't configured).
  static Future<void> initLocalOnly() async {
    await _initLocal();
    startEventPolling();
  }

  static Future<void> _initLocal() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);
    // create a channel for every bundled sound up-front
    for (final s in kAlertSounds) {
      await _ensureChannel(s);
    }
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
        Uri.https(ApiService.pushServer, '/push/register_token.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_api_hash': ApiService.hash,
          'token': token,
          'sound': sound.id,
          'platform': 'android',
          'email': ApiService.userEmail ?? '',
        }),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // backend may not be deployed yet; ignore silently
    }
  }

  // ===== In-app alert polling (works without Firebase/webhook) =====
  // Checks recent events every 30s while the app is open and shows a local
  // notification for any new alert. This makes app alerts work immediately.
  static Timer? _pollTimer;
  static final Set<String> _seenEvents = {};
  static bool _primed = false;

  static void startEventPolling() {
    _pollTimer?.cancel();
    _primed = false;
    _seenEvents.clear();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkEvents());
    _checkEvents();
  }

  static void stopEventPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  static Future<void> _checkEvents() async {
    if (!ApiService.isLoggedIn) return;
    try {
      final events = await ApiService.getEvents();
      // first run: mark old events as seen, but still notify VERY recent ones
      // (last 3 min) so a freshly-fired alert shows during testing.
      if (!_primed) {
        final cutoff = DateTime.now().subtract(const Duration(minutes: 3));
        for (final e in events) {
          _seenEvents.add('${e['id']}');
          final t = DateTime.tryParse('${e['time']}'.replaceFirst(' ', 'T'));
          if (t != null && t.isAfter(cutoff)) {
            final msg = (e['message'] ?? 'Vehicle alert').toString();
            await _showLocal(msg, (e['address'] ?? '').toString(), type: _guessAlertType(msg));
          }
        }
        _primed = true;
        return;
      }
      for (final e in events) {
        final id = '${e['id']}';
        if (_seenEvents.contains(id)) continue;
        _seenEvents.add(id);
        final msg = (e['message'] ?? 'Vehicle alert').toString();
        await _showLocal(msg, (e['address'] ?? '').toString(), type: _guessAlertType(msg));
      }
    } catch (_) {}
  }

  // map an event message to an alert type so the right per-type sound plays
  static String? _guessAlertType(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('speed')) return 'overspeed';
    if (m.contains('offline') || m.contains('lost connection') || m.contains('no signal')) return 'offline';
    if (m.contains('engine on') || (m.contains('ignition') && m.contains('on'))) return 'engine_on';
    if (m.contains('engine off') || (m.contains('ignition') && m.contains('off'))) return 'engine_off';
    if (m.contains('ignition') || m.contains('engine')) return 'engine_on';
    if (m.contains('move') || m.contains('motion')) return 'move_duration';
    if (m.contains('power') || m.contains('unplug')) return 'powercut';
    if (m.contains('battery')) return 'lowbattery';
    return null;
  }

  static Future<void> _showLocal(String title, String body, {String? type}) async {
    // pick the sound chosen for this alert type (falls back to global, then default)
    final sound = type != null ? await soundForType(type) : await currentSound();
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
    await _fln.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, NotificationDetails(android: details));
  }
}

/// Top-level background handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Background/terminated messages with a `notification` payload are shown by
  // the system automatically using the channel specified in `android.channelId`.
  // No action needed here for display.
}
