import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final String ext; // file extension: 'mp3' or 'wav'
  const AlertSound(this.id, this.label, this.file, [this.category = 'Other Tones', this.ext = 'mp3']);
}

// Sound categories shown when creating an alert.
const kSoundCategories = <String>['Default', 'English', 'Hindi', 'Telugu', 'Other Tones'];

const kAlertSounds = <AlertSound>[
  // Default = phone's default notification sound (no file needed)
  AlertSound('default', 'Default Notification', 'default', 'Default'),

  // English voice audios (.wav)
  AlertSound('en_engon', 'Engine On', 'en_engon', 'English', 'wav'),
  AlertSound('en_engoff', 'Engine Off', 'en_engoff', 'English', 'wav'),
  AlertSound('en_speed', 'Speed', 'en_speed', 'English', 'wav'),
  AlertSound('en_online', 'Online', 'en_online', 'English', 'wav'),
  AlertSound('en_offline', 'Offline', 'en_offline', 'English', 'wav'),

  // Hindi voice audios (.wav)
  AlertSound('hi_eng_on', 'Engine On', 'hi_eng_on', 'Hindi', 'wav'),
  AlertSound('hi_eng_off', 'Engine Off', 'hi_eng_off', 'Hindi', 'wav'),
  AlertSound('hi_speed', 'Speed', 'hi_speed', 'Hindi', 'wav'),
  AlertSound('hi_online', 'Online', 'hi_online', 'Hindi', 'wav'),
  AlertSound('hi_offline', 'Offline', 'hi_offline', 'Hindi', 'wav'),

  // Telugu voice audios (.wav)
  AlertSound('te_engon', 'Engine On', 'te_engon', 'Telugu', 'wav'),
  AlertSound('te_engoff', 'Engine Off', 'te_engoff', 'Telugu', 'wav'),
  AlertSound('te_speed', 'Speed', 'te_speed', 'Telugu', 'wav'),
  AlertSound('te_online', 'Online', 'te_online', 'Telugu', 'wav'),
  AlertSound('te_offline', 'Offline', 'te_offline', 'Telugu', 'wav'),

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
  // Bump this when sound files change. Android locks a channel's sound at
  // creation, so a new version forces fresh channels that pick up the .wav/.mp3
  // sounds (old silent channels are deleted on init).
  static const _chanVer = 'v2';
  static String _chanId(String soundId) => 'bgps_alerts_${_chanVer}_$soundId';

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
    final android = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // remove old (possibly silent) channels from previous versions so the
    // fresh versioned channels below pick up the correct sound files
    try {
      final existing = await android?.getNotificationChannels();
      for (final c in existing ?? []) {
        if (c.id.startsWith('bgps_alerts_') && !c.id.startsWith('bgps_alerts_${_chanVer}_')) {
          await android?.deleteNotificationChannel(c.id);
        }
      }
    } catch (_) {}
    // create a channel for every bundled sound up-front
    for (final s in kAlertSounds) {
      await _ensureChannel(s);
    }
  }

  static AndroidNotificationChannel _channelFor(AlertSound s) {
    return AndroidNotificationChannel(
      _chanId(s.id),
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
    final n = m.notification;
    final title = n?.title ?? m.data['title'] ?? 'BharatGPS Alert';
    final body = n?.body ?? m.data['body'] ?? '';
    // pick the sound chosen for THIS alert type (not the global one).
    // type can come from the push data, else guess from the text.
    final type = (m.data['type'] ?? m.data['alert_type'] ?? _guessAlertType('$title $body'))?.toString();
    final sound = (type != null && type.isNotEmpty) ? await soundForType(type) : await currentSound();
    final details = AndroidNotificationDetails(
      _chanId(sound.id),
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

  /// Preview a sound immediately — plays the audio file directly from assets
  /// (reliable, audible). Returns null on success, or an error message.
  static final AudioPlayer _previewPlayer = AudioPlayer();
  static Future<String?> preview(AlertSound s) async {
    if (s.file == 'default') {
      await _ensureChannel(s);
      await _fln.show(99999, 'Sound preview', 'Default notification tone',
          NotificationDetails(android: AndroidNotificationDetails(
            _chanId('default'), 'Alerts — Default',
            importance: Importance.high, priority: Priority.high, playSound: true,
            icon: '@mipmap/ic_launcher',
          )));
      return null;
    }
    try {
      await _previewPlayer.stop();
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      // play from bundled assets: assets/sounds/<file>.mp3
      await _previewPlayer.play(AssetSource('sounds/${s.file}.${s.ext}'));
      return null;
    } catch (e) {
      return 'Preview failed: $e';
    }
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
    _statesPrimed = false;
    _seenEvents.clear();
    _lastMotion.clear();
    _lastCharge.clear();
    _lastIgnition.clear();
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
    // also detect motion / power / ignition changes directly from device data
    await _checkDeviceStates();
  }

  // ===== App-side detection of motion, power (charge) and ignition =====
  // Watches each device's live values and notifies when they change. This makes
  // Movement, Power Cut and Engine ON/OFF alerts work without server alert types.
  static final Map<String, String> _lastMotion = {};
  static final Map<String, String> _lastCharge = {};
  static final Map<String, String> _lastIgnition = {};
  static bool _statesPrimed = false;

  // per-type enable flags (default ON). Pref keys: bgps_detect_<type>
  static Future<bool> _detectEnabled(String type) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('bgps_detect_$type') ?? true;
  }

  static Future<void> setDetectEnabled(String type, bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('bgps_detect_$type', on);
  }

  static String _b(dynamic v) {
    final s = '$v'.trim().toLowerCase();
    if (s == 'true' || s == '1') return 'true';
    if (s == 'false' || s == '0') return 'false';
    return '';
  }

  static Future<void> _checkDeviceStates() async {
    if (!ApiService.isLoggedIn) return;
    try {
      final devices = await ApiService.getDevices();
      // first pass: just record current states, don't notify (avoids a burst)
      if (!_statesPrimed) {
        for (final d in devices) {
          final id = '${d['id']}';
          final ts = (d['ts'] is Map) ? d['ts'] as Map : const {};
          _lastMotion[id] = _b(ts['motion']);
          _lastCharge[id] = _b(ts['charge']);
          _lastIgnition[id] = _b(ts['ignition']);
        }
        _statesPrimed = true;
        return;
      }

      for (final d in devices) {
        final id = '${d['id']}';
        final name = '${d['name'] ?? 'Vehicle'}';
        final ts = (d['ts'] is Map) ? d['ts'] as Map : const {};
        final motion = _b(ts['motion']);
        final charge = _b(ts['charge']);
        final ign = _b(ts['ignition']);

        // MOVEMENT: motion false -> true
        final pm = _lastMotion[id];
        if (motion.isNotEmpty && pm != null && pm.isNotEmpty && motion != pm) {
          if (motion == 'true' && await _detectEnabled('move_duration')) {
            await _showLocal('$name started moving', 'Vehicle is now in motion', type: 'move_duration');
          }
          _lastMotion[id] = motion;
        } else if (motion.isNotEmpty) {
          _lastMotion[id] = motion;
        }

        // POWER CUT: charge true -> false (power disconnected)
        final pc = _lastCharge[id];
        if (charge.isNotEmpty && pc != null && pc.isNotEmpty && charge != pc) {
          if (charge == 'false' && await _detectEnabled('powercut')) {
            await _showLocal('$name power disconnected', 'GPS device main power was cut', type: 'powercut');
          } else if (charge == 'true' && await _detectEnabled('powercut')) {
            await _showLocal('$name power restored', 'GPS device main power is back', type: 'powercut');
          }
          _lastCharge[id] = charge;
        } else if (charge.isNotEmpty) {
          _lastCharge[id] = charge;
        }

        // IGNITION: on/off change
        final pi = _lastIgnition[id];
        if (ign.isNotEmpty && pi != null && pi.isNotEmpty && ign != pi) {
          if (ign == 'true' && await _detectEnabled('engine_on')) {
            await _showLocal('$name engine ON', 'Ignition turned on', type: 'engine_on');
          } else if (ign == 'false' && await _detectEnabled('engine_off')) {
            await _showLocal('$name engine OFF', 'Ignition turned off', type: 'engine_off');
          }
          _lastIgnition[id] = ign;
        } else if (ign.isNotEmpty) {
          _lastIgnition[id] = ign;
        }
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
      _chanId(sound.id),
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
