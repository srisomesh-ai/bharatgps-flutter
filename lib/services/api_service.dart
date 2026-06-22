import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Talks directly to the BharatGPS (Traccar-based) API. No PHP proxy.
class ApiService {
  static const servers = ['bharatgps.com', 'bharatgps.in', 'bharatgps.school'];

  /// The server that hosts the push notification PHP files (register_token.php,
  /// alert_webhook.php). This is the user's own Hostinger panel domain (full file
  /// access), NOT the GPSWOX tracking server.
  static const pushServer = 'lightcyan-hare-594583.hostingersite.com';

  static String? hash;
  static String? host;
  static String? userName;
  static String? userEmail;

  static Future<void> loadSession() async {
    final p = await SharedPreferences.getInstance();
    hash = p.getString('bgps_hash');
    host = p.getString('bgps_host');
    userName = p.getString('bgps_user');
    userEmail = p.getString('bgps_email');
  }

  static Future<void> saveSession(String h, String server, String user, String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('bgps_hash', h);
    await p.setString('bgps_host', server);
    await p.setString('bgps_user', user);
    if (email.isNotEmpty) await p.setString('bgps_email', email);
    hash = h;
    host = server;
    userName = user;
    userEmail = email;
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('bgps_hash');
    await p.remove('bgps_host');
    await p.remove('bgps_user');
    hash = null;
    host = null;
  }

  static bool get isLoggedIn => hash != null && host != null;

  static Uri _u(String server, String path, Map<String, String> q) {
    return Uri.https(server, '/api/$path', q);
  }

  /// LOGIN — tries each server until one authenticates.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    for (final server in servers) {
      try {
        final res = await http.post(
          Uri.https(server, '/api/login'),
          body: {'email': email, 'password': password},
        ).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) {
          final j = jsonDecode(res.body);
          if (j is Map && (j['status'] == 1 || j['user_api_hash'] != null)) {
            final h = j['user_api_hash'] ?? '';
            final user = (j['user']?['name'] ?? j['user']?['email'] ?? email).toString();
            if (h.toString().isNotEmpty) {
              await saveSession(h.toString(), server, user, email);
              return {'ok': true, 'server': server};
            }
          }
        }
      } catch (_) {
        // try next server
      }
    }
    return {'ok': false, 'error': 'Invalid credentials or no server reachable'};
  }

  /// DEVICES — flattened list.
  // last successful device list — lets screens render instantly while refreshing
  static List<Map<String, dynamic>> cachedDevices = [];

  static Future<List<Map<String, dynamic>>> getDevices() async {
    final res = await http.get(_u(host!, 'get_devices', {
      'lang': 'en',
      'user_api_hash': hash!,
      'limit': '1000',
    })).timeout(const Duration(seconds: 25));
    final out = <Map<String, dynamic>>[];
    if (res.statusCode != 200) return out;
    final j = jsonDecode(res.body);
    if (j is List) {
      for (final group in j) {
        if (group is! Map) continue;
        final items = group['items'] is List ? group['items'] : (group['id'] != null ? [group] : []);
        for (final d in items) {
          if (d is Map) out.add(_mapDevice(Map<String, dynamic>.from(d)));
        }
      }
    }
    if (out.isNotEmpty) cachedDevices = out;
    return out;
  }

  static Map<String, dynamic> _mapDevice(Map<String, dynamic> d) {
    final dd = (d['device_data'] is Map) ? Map<String, dynamic>.from(d['device_data']) : {};
    final tr = (dd['traccar'] is Map) ? Map<String, dynamic>.from(dd['traccar']) : {};
    final xml = (tr['other'] ?? '').toString();
    String? xmlTag(String tag) {
      final m = RegExp('<$tag>(.*?)</$tag>', caseSensitive: false).firstMatch(xml);
      return m?.group(1);
    }

    return {
      'id': d['id'],
      'name': d['name'] ?? 'Vehicle',
      'online': d['online'],
      'speed': d['speed'] ?? 0,
      'lat': d['lat'] ?? d['latitude'],
      'lng': d['lng'] ?? d['longitude'],
      'time': d['time'],
      'course': double.tryParse('${d['course'] ?? 0}') ?? 0,
      'address': (d['address'] != null && d['address'].toString() != '-' && d['address'].toString().isNotEmpty) ? d['address'] : '',
      'model': dd['device_model'] ?? dd['model'] ?? d['model'] ?? '',
      'plate': dd['plate_number'] ?? d['plate'] ?? '',
      'icon_url': _iconUrl(d),
      'total_distance': d['total_distance'],
      'expiry': _firstValidDate([
        dd['expiration_date'], d['expiration_date'],
        dd['expires_date'], d['expires_date'],
        dd['expires'], d['expires'],
        dd['subscription_expiration'], d['subscription_expiration'],
        dd['sim_expiration_date'], d['sim_expiration_date'],
      ]) ?? _scanExpiry(dd) ?? _scanExpiry(d),
      'expiry_raw': dd.entries.map((e) => '${e.key}=${e.value}').where((s) => s.toLowerCase().contains('exp') || s.toLowerCase().contains('date') || s.toLowerCase().contains('valid') || s.toLowerCase().contains('renew') || s.toLowerCase().contains('subscrib')).join('\n'),
      'device_data_keys': dd.keys.join(', '),
      'tail': (d['tail'] is List)
          ? (d['tail'] as List)
              .where((p) => p is Map && p['lat'] != null && p['lng'] != null)
              .map((p) => {'lat': double.tryParse('${p['lat']}') ?? 0, 'lng': double.tryParse('${p['lng']}') ?? 0})
              .toList()
          : [],
      'ts': {
        'ignition': xmlTag('ignition'),
        'charge': xmlTag('charge'),
        'blocked': xmlTag('blocked'),
        'valid': xmlTag('valid'),
        'motion': xmlTag('motion'),
        'battery': xmlTag('batterylevel'),
        'rssi': xmlTag('rssi'),
        'alarm': d['alarm'],
      },
    };
  }

  // returns the first non-empty, non-zero date string, else null
  static String? _firstValidDate(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isEmpty || s.startsWith('0000') || s == 'null') continue;
      return s;
    }
    return null;
  }

  // fallback: scan any map for a key containing 'expir'/'expire' with a real date value
  static String? _scanExpiry(Map m) {
    for (final entry in m.entries) {
      final k = entry.key.toString().toLowerCase();
      if (k.contains('expir') || k.contains('expire')) {
        final s = '${entry.value}'.trim();
        if (s.isNotEmpty && !s.startsWith('0000') && s != 'null' && RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(s)) {
          return s;
        }
      }
    }
    return null;
  }

  static String? _iconUrl(Map d) {
    final icon = d['icon'];
    if (icon is Map && icon['path'] != null) {
      final p = icon['path'].toString();
      if (p.startsWith('http')) return p;
      return 'https://${host!}/$p';
    }
    return null;
  }

  /// HISTORY — route points for a date range (Traccar get_history_messages).
  static Future<Map<String, dynamic>> getHistory({
    required String deviceId,
    int? days,
    DateTime? from,
    DateTime? to,
  }) async {
    DateTime fromDt, toDt;
    if (from != null && to != null) {
      fromDt = from;
      toDt = to;
    } else {
      final d = (days ?? 1);
      toDt = DateTime.now();
      fromDt = DateTime(toDt.year, toDt.month, toDt.day);
      if (d > 1) fromDt = fromDt.subtract(Duration(days: d - 1));
    }
    String dd(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    String tt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    final points = <Map<String, dynamic>>[];
    int page = 1, lastPage = 1;
    do {
      final res = await http.get(_u(host!, 'get_history_messages', {
        'lang': 'en',
        'user_api_hash': hash!,
        'device_id': deviceId,
        'from_date': dd(fromDt),
        'from_time': tt(fromDt),
        'to_date': dd(toDt),
        'to_time': tt(toDt),
        'limit': '500',
        'page': '$page',
      })).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) break;
      final j = jsonDecode(res.body);
      final msg = (j is Map && j['messages'] is Map) ? j['messages'] : j;
      if (page == 1) lastPage = (msg['last_page'] ?? 1) is int ? msg['last_page'] : int.tryParse('${msg['last_page']}') ?? 1;
      final data = (msg['data'] is List) ? msg['data'] : [];
      for (final r in data) {
        if (r is! Map) continue;
        final la = r['latitude'], lo = r['longitude'];
        if (la == null || lo == null || la == '' || lo == '') continue;
        points.add({
          'lat': double.tryParse(la.toString()) ?? 0,
          'lng': double.tryParse(lo.toString()) ?? 0,
          'spd': (double.tryParse('${r['speed'] ?? 0}') ?? 0).round(),
          't': r['time'] ?? r['server_time'] ?? '',
        });
      }
      page++;
    } while (page <= min(lastPage, 20));

    // haversine distance + stops
    double dist = 0;
    for (int i = 1; i < points.length; i++) {
      dist += _haversine(points[i - 1], points[i]);
    }
    final stops = <Map<String, dynamic>>[];
    int i = 0;
    while (i < points.length) {
      if ((points[i]['spd'] as int) <= 2) {
        int j = i;
        while (j < points.length && (points[j]['spd'] as int) <= 2) {
          j++;
        }
        final t0 = DateTime.tryParse(points[i]['t'].toString().replaceFirst(' ', 'T'));
        final t1 = DateTime.tryParse(points[j - 1]['t'].toString().replaceFirst(' ', 'T'));
        if (t0 != null && t1 != null) {
          final secs = t1.difference(t0).inSeconds;
          if (secs >= 300) {
            stops.add({'lat': points[i]['lat'], 'lng': points[i]['lng'], 'mins': (secs / 60).round()});
          }
        }
        i = j;
      } else {
        i++;
      }
    }

    return {
      'points': points,
      'distance_km': double.parse(dist.toStringAsFixed(2)),
      'stops': stops,
    };
  }

  static double _haversine(Map a, Map b) {
    const r = 6371.0;
    final dLat = _rad(b['lat'] - a['lat']);
    final dLng = _rad(b['lng'] - a['lng']);
    final x = pow(sin(dLat / 2), 2) + cos(_rad(a['lat'])) * cos(_rad(b['lat'])) * pow(sin(dLng / 2), 2);
    return r * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  static double _rad(num d) => d * pi / 180.0;

  /// Today's stats from real history (matches history report).
  /// Auto-detect trips from GPS history (no manual start/stop).
  /// A trip = continuous movement; it ends after the vehicle is stopped for
  /// [stopMinutes]. Works even if the app was closed, because the server logs all points.
  static Future<List<Map<String, dynamic>>> getTrips({
    required String deviceId,
    int days = 1,
    DateTime? from,
    DateTime? to,
    int stopMinutes = 5,
    int moveSpeed = 3, // km/h above which the vehicle is "moving"
  }) async {
    final hist = (from != null && to != null)
        ? await getHistory(deviceId: deviceId, from: from, to: to)
        : await getHistory(deviceId: deviceId, days: days);
    final pts = (hist['points'] as List?) ?? [];
    final trips = <Map<String, dynamic>>[];
    if (pts.isEmpty) return trips;

    List<Map<String, dynamic>> cur = [];
    DateTime? lastMove;
    DateTime? pt(dynamic t) => DateTime.tryParse('$t'.replaceFirst(' ', 'T'));

    void closeTrip() {
      if (cur.length < 2) {
        cur = [];
        return;
      }
      double dist = 0;
      int maxSpd = 0;
      for (int i = 1; i < cur.length; i++) {
        dist += _haversine(cur[i - 1], cur[i]);
        final s = (cur[i]['spd'] as num).toInt();
        if (s > maxSpd) maxSpd = s;
      }
      final t0 = pt(cur.first['t']);
      final t1 = pt(cur.last['t']);
      if (t0 == null || t1 == null || dist < 0.3) {
        cur = [];
        return;
      }
      trips.add({
        'start': cur.first['t'],
        'end': cur.last['t'],
        'startLat': cur.first['lat'],
        'startLng': cur.first['lng'],
        'endLat': cur.last['lat'],
        'endLng': cur.last['lng'],
        'distance': double.parse(dist.toStringAsFixed(1)),
        'duration_min': t1.difference(t0).inMinutes,
        'max_speed': maxSpd,
        'points': List<Map<String, dynamic>>.from(cur),
      });
      cur = [];
    }

    for (final p in pts) {
      final spd = (p['spd'] as num?)?.toInt() ?? 0;
      final t = pt(p['t']);
      if (spd >= moveSpeed) {
        cur.add(Map<String, dynamic>.from(p));
        lastMove = t;
      } else {
        if (cur.isNotEmpty && lastMove != null && t != null) {
          if (t.difference(lastMove).inMinutes >= stopMinutes) {
            closeTrip();
          } else {
            cur.add(Map<String, dynamic>.from(p));
          }
        }
      }
    }
    closeTrip();
    trips.sort((a, b) => '${b['start']}'.compareTo('${a['start']}'));
    return trips;
  }

  static Future<Map<String, dynamic>> getDayStats(String deviceId) async {
    final h = await getHistory(deviceId: deviceId, days: 1);
    final pts = h['points'] as List;
    int maxSpd = 0, moveSec = 0;
    for (int i = 0; i < pts.length; i++) {
      if ((pts[i]['spd'] as int) > maxSpd) maxSpd = pts[i]['spd'];
      if (i > 0 && (pts[i]['spd'] as int) > 2) {
        final t0 = DateTime.tryParse(pts[i - 1]['t'].toString().replaceFirst(' ', 'T'));
        final t1 = DateTime.tryParse(pts[i]['t'].toString().replaceFirst(' ', 'T'));
        if (t0 != null && t1 != null) {
          final s = t1.difference(t0).inSeconds;
          if (s > 0 && s < 3600) moveSec += s;
        }
      }
    }
    final hrs = moveSec / 3600.0;
    final H = hrs.floor();
    final M = ((hrs - H) * 60).round();
    return {
      'distance_today': h['distance_km'],
      'hours_today': '${H > 0 ? '${H}h ' : ''}${M}m',
      'max_speed_today': maxSpd,
    };
  }

  /// ENGINE CUT-OFF — list of devices that accept GPRS commands.
  static Future<List<String>> getCommandDevices() async {
    final res = await http.get(_u(host!, 'send_command_data', {
      'lang': 'en',
      'user_api_hash': hash!,
    })).timeout(const Duration(seconds: 20));
    final out = <String>[];
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j is Map && j['devices_gprs'] is List) {
        for (final d in j['devices_gprs']) {
          if (d is Map && d['id'] != null) out.add(d['id'].toString());
        }
      }
    }
    return out;
  }

  static Future<bool> sendEngineCommand(String deviceId, String command) async {
    // command: engineStop | engineResume
    final res = await http.post(
      _u(host!, 'send_gprs_command', {'lang': 'en', 'user_api_hash': hash!}),
      body: {'device_id': deviceId, 'type': command, 'message': ''},
    ).timeout(const Duration(seconds: 30));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j is Map && (j['status'] == 1 || j['success'] == true)) return true;
    }
    return false;
  }

  /// ALERTS
  static Future<List<Map<String, dynamic>>> getAlerts() async {
    final res = await http.get(_u(host!, 'get_alerts', {'lang': 'en', 'user_api_hash': hash!}))
        .timeout(const Duration(seconds: 20));
    final out = <Map<String, dynamic>>[];
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      final items = (j is Map && j['items'] is Map && j['items']['alerts'] is List)
          ? j['items']['alerts']
          : ((j is Map && j['items'] is List) ? j['items'] : []);
      for (final a in items) {
        if (a is! Map) continue;
        out.add({
          'id': a['id'],
          'name': a['name'] ?? 'Alert',
          'type': a['type'] ?? (a['overspeed_speed'] != null ? 'overspeed' : ''),
          'active': (a['active'] ?? 1) is int ? a['active'] : int.tryParse('${a['active']}') ?? 1,
          'overspeed': a['overspeed_speed'] ?? a['overspeed'],
          'move_duration': a['move_duration'],
          'ignition_duration': a['ignition_duration'],
          'devices': a['devices'] ?? [],
        });
      }
    }
    return out;
  }

  static Future<bool> createAlert({
    required String type,
    required String name,
    required List<int> devices,
    int? overspeed,
    int? moveDuration,
    int? ignitionDuration,
  }) async {
    final payload = {
      'active': 1,
      'type': type,
      'name': name,
      'devices': devices,
      'notifications': {
        'push': {'active': 1},
        'popup': {'active': 1, 'input': 0},
      },
    };
    if (type == 'overspeed') payload['overspeed'] = overspeed ?? 60;
    if (type == 'move_duration') payload['move_duration'] = moveDuration ?? 1;
    if (type == 'ignition_duration') payload['ignition_duration'] = ignitionDuration ?? 1;

    final res = await http.post(
      _u(host!, 'add_alert', {'lang': 'en', 'user_api_hash': hash!}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      if (j is Map && (j['status'] == 1 || j['id'] != null || j['success'] == true)) return true;
    }
    return false;
  }

  static Future<bool> toggleAlert(int id) async {
    final res = await http.get(_u(host!, 'change_active_alert', {
      'lang': 'en',
      'user_api_hash': hash!,
      'alert_id': '$id',
    })).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j is Map && (j['status'] == 1 || j['success'] == true);
    }
    return false;
  }

  static Future<bool> deleteAlert(int id) async {
    final res = await http.get(_u(host!, 'destroy_alert', {
      'lang': 'en',
      'user_api_hash': hash!,
      'id': '$id',
    })).timeout(const Duration(seconds: 20));
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body);
      return j is Map && (j['status'] == 1 || j['success'] == true);
    }
    return false;
  }

  /// EVENTS history (last 7 days default).
  static Future<List<Map<String, dynamic>>> getEvents() async {
    final now = DateTime.now();
    final fromDay = now.subtract(const Duration(days: 7));
    String dd(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final dateFrom = '${dd(fromDay)} 00:00:00';
    final dateTo = '${dd(now)} 23:59:59';
    final out = <Map<String, dynamic>>[];
    try {
      final res = await http.get(_u(host!, 'get_events', {
        'lang': 'en',
        'user_api_hash': hash!,
        'date_from': dateFrom,
        'date_to': dateTo,
      })).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return out;
      final j = jsonDecode(res.body);
      // GPSWOX nests events at items.data[]; some servers return data[] or a bare list
      List data = [];
      if (j is List) {
        data = j;
      } else if (j is Map) {
        if (j['items'] is Map && j['items']['data'] is List) {
          data = j['items']['data'];
        } else if (j['items'] is List) {
          data = j['items'];
        } else if (j['data'] is List) {
          data = j['data'];
        } else if (j['events'] is List) {
          data = j['events'];
        }
      }
      for (final e in data) {
        if (e is! Map) continue;
        out.add({
          'id': e['id'] ?? e['event_id'] ?? '${e['device_id']}_${e['created_at'] ?? e['time']}',
          'device_id': e['device_id'],
          'message': e['message'] ?? e['name'] ?? e['type'] ?? 'Alert',
          'time': e['time'] ?? e['created_at'] ?? e['updated_at'] ?? '',
          'address': e['address'] ?? '',
          'speed': e['speed'],
        });
      }
    } catch (_) {}
    return out;
  }

  /// Debug: returns the raw get_events response body (for troubleshooting).
  static Future<String> getEventsRaw() async {
    final now = DateTime.now();
    final fromDay = now.subtract(const Duration(days: 7));
    String dd(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    try {
      final res = await http.get(_u(host!, 'get_events', {
        'lang': 'en',
        'user_api_hash': hash!,
        'date_from': '${dd(fromDay)} 00:00:00',
        'date_to': '${dd(now)} 23:59:59',
      })).timeout(const Duration(seconds: 25));
      return 'HTTP ${res.statusCode}\nhost: $host\n\n${res.body}';
    } catch (e) {
      return 'ERROR: $e';
    }
  }

  /// USER plan/profile data.
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final res = await http.get(_u(host!, 'get_user_data', {'lang': 'en', 'user_api_hash': hash!}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j is Map) return Map<String, dynamic>.from(j);
      }
    } catch (_) {}
    return null;
  }

  /// Reverse-geocode lat/lng -> readable address (OpenStreetMap Nominatim), cached.
  static final Map<String, String> _geoCache = {};
  static Future<String?> reverseGeocode(dynamic lat, dynamic lng) async {
    final la = double.tryParse('$lat'), lo = double.tryParse('$lng');
    if (la == null || lo == null) return null;
    final key = '${la.toStringAsFixed(4)},${lo.toStringAsFixed(4)}';
    if (_geoCache.containsKey(key)) return _geoCache[key];
    try {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&zoom=16&lat=$la&lon=$lo'),
        headers: {'User-Agent': 'BharatGPS-App/1.0'},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final name = (j is Map) ? j['display_name']?.toString() : null;
        if (name != null && name.isNotEmpty) {
          _geoCache[key] = name;
          return name;
        }
      }
    } catch (_) {}
    return null;
  }
}
