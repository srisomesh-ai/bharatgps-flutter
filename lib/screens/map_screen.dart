import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import 'troubleshoot_sheet.dart';
import 'history_map_screen.dart';
import '../widgets/loaders.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  List<String> _gprsDevices = [];
  dynamic _focusId;
  String _search = '';
  String _mapType = 'normal'; // normal | google | satellite | hybrid
  bool _showNames = true;
  Map<String, dynamic>? _selected; // for the mini-card
  Timer? _refresh;
  final Map<String, String> _addrCache = {};

  // ===== glide engine state =====
  // per-vehicle animated position + animation source/target + tail trail
  final Map<String, LatLng> _animPos = {};   // current on-screen position
  final Map<String, LatLng> _srcPos = {};     // glide start
  final Map<String, LatLng> _dstPos = {};     // glide target
  final Map<String, double> _heading = {};    // current heading (deg)
  final Map<String, List<LatLng>> _tail = {}; // trail points (only while moving)
  Ticker? _ticker;
  int _glideStartMs = 0;
  double _pulseValue = 0; // 0..1 pulse phase for running markers
  double _mapRotation = 0; // current map rotation in degrees (to keep labels upright)
  int _lastDrop = 0; // last breadcrumb drop time (ms)
  static const _glideMs = 5000;   // matches web GLIDE_MS / POLL_MS
  static const _maxTail = 40;

  @override
  void initState() {
    super.initState();
    // Map is LIVE — always load fresh (don't seed from cache). Stale cached
    // position/heading/tail would mislead the user into thinking it's current.
    // seed focus from any pending request (e.g. tapped from dashboard)
    _focusId = MainShell.mapFocusId.value;
    MainShell.mapFocusId.addListener(_onFocusRequested);
    _load();
    _loadGprs();
    _refresh = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
    _ticker = createTicker(_onTick)..start();
  }

  void _onFocusRequested() {
    final id = MainShell.mapFocusId.value;
    if (id == null) return;
    _focusId = id;
    // focus immediately if we already have the device loaded
    final u = _devices.firstWhere((e) => '${e['id']}' == '$id', orElse: () => {});
    if (u.isNotEmpty && u['lat'] != null) {
      _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 15);
      setState(() => _selected = u);
      _focusId = null;
      MainShell.mapFocusId.value = null;
    } else {
      _load(); // not loaded yet — fetch then the focus block in _load handles + clears it
    }
  }

  void _onTick(Duration elapsed) {
    // pulse phase (1.6s loop) for running-vehicle glow
    _pulseValue = (elapsed.inMilliseconds % 1600) / 1600.0;
    if (_dstPos.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final k = ((now - _glideStartMs) / _glideMs).clamp(0.0, 1.0);
    final dropNow = (now - _lastDrop) >= 180; // web DROP_EVERY = 180ms
    for (final id in _dstPos.keys) {
      final src = _srcPos[id], dst = _dstPos[id];
      if (src == null || dst == null) continue;
      final lat = src.latitude + (dst.latitude - src.latitude) * k;
      final lng = src.longitude + (dst.longitude - src.longitude) * k;
      final np = LatLng(lat, lng);
      _animPos[id] = np;
      // drop tail breadcrumbs while gliding (only for moving vehicles)
      final dev = _devices.firstWhere((e) => '${e['id']}' == id, orElse: () => {});
      final moving = dev.isNotEmpty && stateOf(dev['online'], dev['speed']) == 'rn';
      if (moving && dropNow) {
        final t = _tail.putIfAbsent(id, () => []);
        if (t.isEmpty || t.last != np) {
          t.add(np);
          if (t.length > _maxTail) t.removeAt(0);
        }
      }
      // follow selected vehicle
      if (moving && _selected != null && '${_selected!['id']}' == id) {
        _map.move(np, _map.camera.zoom);
      }
    }
    if (dropNow) _lastDrop = now;
    // rebuild every frame so glide + pulse animate smoothly
    if (mounted) setState(() {});
  }


  @override
  void dispose() {
    MainShell.mapFocusId.removeListener(_onFocusRequested);
    _refresh?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusId ??= ModalRoute.of(context)?.settings.arguments;
  }

  Future<void> _load({bool silent = false}) async {
    final d = await ApiService.getDevices();
    if (!mounted) return;
    // keep the selected vehicle's reference fresh
    if (_selected != null) {
      final match = d.firstWhere((e) => '${e['id']}' == '${_selected!['id']}', orElse: () => {});
      if (match.isNotEmpty) _selected = match;
    }
    // set up glide: each vehicle animates from current anim position to new GPS target
    for (final u in d) {
      if (u['lat'] == null || u['lng'] == null) continue;
      final id = '${u['id']}';
      final target = LatLng(_toD(u['lat']), _toD(u['lng']));
      final cur = _animPos[id] ?? target;
      // if the vehicle jumped a long way (teleport / first fix / big gap), snap instead of drawing a line across
      final jump = (cur.latitude - target.latitude).abs() > 0.05 || (cur.longitude - target.longitude).abs() > 0.05;
      _srcPos[id] = jump ? target : cur;
      _dstPos[id] = target;
      _animPos[id] = jump ? target : (_animPos[id] ?? target);
      _heading[id] = _toD(u['course']).toDouble();
      // reset tail if vehicle is not moving OR jumped
      final moving = stateOf(u['online'], u['speed']) == 'rn';
      if (!moving || jump) _tail[id] = [];
    }
    _glideStartMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _devices = d;
      _loading = false;
    });
    _resolveAddresses(d);
    if (!silent && _focusId != null) {
      final u = _devices.firstWhere((e) => '${e['id']}' == '$_focusId', orElse: () => {});
      if (u.isNotEmpty && u['lat'] != null) {
        _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 15);
        setState(() => _selected = u);
      }
      _focusId = null;
      MainShell.mapFocusId.value = null;
    }
  }

  // reverse-geocode any device whose address is empty
  Future<void> _resolveAddresses(List<Map<String, dynamic>> devs) async {
    for (final u in devs) {
      if ((u['address'] ?? '').toString().isNotEmpty) continue;
      final key = '${u['id']}';
      if (_addrCache.containsKey(key)) {
        u['address'] = _addrCache[key];
        continue;
      }
      if (u['lat'] == null || u['lng'] == null) continue;
      final name = await ApiService.reverseGeocode(u['lat'], u['lng']);
      if (name != null && mounted) {
        _addrCache[key] = name;
        setState(() {
          u['address'] = name;
          if (_selected != null && '${_selected!['id']}' == key) _selected!['address'] = name;
        });
      }
    }
  }

  Future<void> _loadGprs() async {
    final g = await ApiService.getCommandDevices();
    if (mounted) setState(() => _gprsDevices = g);
  }

  double _toD(dynamic v) => double.tryParse('$v') ?? 0;

  // vehicles matching the current search
  List<Map<String, dynamic>> _visibleDevices({bool needLatLng = false}) {
    return _devices.where((u) {
      if (needLatLng && (u['lat'] == null || u['lng'] == null)) return false;
      if (_search.isNotEmpty && !(u['name'] ?? '').toString().toLowerCase().contains(_search)) return false;
      return true;
    }).toList();
  }

  void _showVehicleList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 8 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3))),
          Row(children: [
            const Text('Select Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${_devices.length} total', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _devices.map((u) {
                final s = stateOf(u['online'], u['speed']);
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (u['lat'] != null && u['lng'] != null) {
                      _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 16);
                      setState(() => _selected = u);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: stateColor(s), shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: stateBg(s), borderRadius: BorderRadius.circular(20)), child: Text(stateLabels[s]!, style: TextStyle(color: stateColor(s), fontSize: 10, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  // Map tiles. Default = the original CartoDB light style (looks clean).
  // Google modes use Google's tile servers.
  String _tileUrl() {
    switch (_mapType) {
      case 'google':
        return 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=en';
      case 'satellite':
        return 'https://mt{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}&hl=en';
      case 'hybrid':
        return 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}&hl=en';
      default: // 'normal' -> original map
        return 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
    }
  }

  List<String> _tileSubdomains() => _mapType == 'normal' ? const ['a', 'b', 'c', 'd'] : const ['0', '1', '2', '3'];

  // tail trail = breadcrumbs dropped as the vehicle glides (the path already
  // travelled). Only shows BEHIND the vehicle, never a line to the next point.
  List<Polyline> _tailPolylines() {
    final out = <Polyline>[];
    final visible = _visibleDevices();
    for (final u in visible) {
      final id = '${u['id']}';
      final coords = _tail[id] ?? [];
      final live = _animPos[id];
      final pts = <LatLng>[...coords];
      if (live != null) pts.add(live); // trail ends exactly at the vehicle
      if (pts.length < 2) continue;
      final n = pts.length;
      for (int i = 1; i < n; i++) {
        final frac = i / (n - 1);
        out.add(Polyline(
          points: [pts[i - 1], pts[i]],
          color: AppColors.teal.withOpacity((0.10 + frac * 0.6).clamp(0.0, 1.0)),
          strokeWidth: 2 + frac * 3,
        ));
      }
    }
    return out;
  }

  List<Marker> _markers() {
    final visible = _visibleDevices(needLatLng: true);
    return visible.map((u) {
      final s = stateOf(u['online'], u['speed']);
      final id = '${u['id']}';
      final pos = _animPos[id] ?? LatLng(_toD(u['lat']), _toD(u['lng']));
      final heading = _heading[id] ?? _toD(u['course']).toDouble();
      return Marker(
        point: pos,
        width: 200,
        height: 96,
        rotate: true, // keep the marker upright when the map is rotated (labels stay readable)
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = u);
            _map.move(pos, _map.camera.zoom < 13 ? 14 : _map.camera.zoom);
          },
          child: _VehicleMarker(device: u, state: s, heading: heading, pulse: _pulseValue, showName: _showNames, mapRotation: _mapRotation),
        ),
      );
    }).toList();
  }

  void _openDetail(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleDetailSheet(
        device: u,
        supportsCutoff: _gprsDevices.contains('${u['id']}'),
      ),
    );
  }

  void _openTroubleshoot(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TroubleshootSheet(device: u),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = _devices.isNotEmpty && _devices.first['lat'] != null
        ? LatLng(_toD(_devices.first['lat']), _toD(_devices.first['lng']))
        : const LatLng(20.59, 78.96);
    final visible = _visibleDevices();
    return Scaffold(
      body: Column(
        children: [
          // ===== HEADER =====
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.teal2]),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 14),
            child: Column(children: [
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.all(3), child: Image.asset('assets/logo-icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.location_on, color: AppColors.teal, size: 22))),
                const SizedBox(width: 9),
                const Text('Bharat GPS Tracker', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: () => MainShell.of(context)?.goTo(3), icon: const Icon(Icons.notifications_none, color: Colors.white, size: 23), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 14),
                const Icon(Icons.filter_list, color: Colors.white, size: 23),
              ]),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                  onSubmitted: (v) {
                    final q = v.trim().toLowerCase();
                    if (q.isEmpty) return;
                    final match = _devices.where((u) => (u['name'] ?? '').toString().toLowerCase().contains(q) && u['lat'] != null && u['lng'] != null);
                    if (match.isNotEmpty) {
                      final u = match.first;
                      _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 16);
                      setState(() => _selected = u);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search Vehicles',
                    hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: AppColors.muted, size: 21),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
          // ===== MAP (fills everything below header; controls float on top) =====
          Expanded(
            child: Stack(children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _devices.isEmpty ? 5 : 12,
                  onTap: (_, __) => setState(() => _selected = null),
                  onPositionChanged: (camera, _) {
                    // keep marker labels upright as the map rotates
                    final rot = _map.camera.rotation;
                    if ((rot - _mapRotation).abs() > 0.5) {
                      setState(() => _mapRotation = rot);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _tileUrl(),
                    subdomains: _tileSubdomains(),
                    userAgentPackageName: 'com.bharatgps.app',
                    maxZoom: 20,
                  ),
                  PolylineLayer(polylines: _tailPolylines()),
                  MarkerLayer(markers: _markers()),
                ],
              ),
              if (_loading)
                Container(
                  color: AppColors.bg,
                  child: const SatelliteLoader(label: 'Locating vehicles…'),
                ),
              // floating vehicle count + map type (on top of the map)
              Positioned(
                left: 14, right: 14, top: 12,
                child: Row(children: [
                  GestureDetector(
                    onTap: _showVehicleList,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.people_alt_outlined, size: 16, color: AppColors.teal),
                        const SizedBox(width: 6),
                        Text('${visible.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const Icon(Icons.keyboard_arrow_down, size: 17, color: AppColors.ink2),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _segBtn('Map', _mapType == 'normal', () => setState(() => _mapType = 'normal')),
                      _segBtn('Google', _mapType == 'google', () => setState(() => _mapType = 'google')),
                      _segBtn('Sat', _mapType == 'satellite', () => setState(() => _mapType = 'satellite')),
                      _segBtn('Hybrid', _mapType == 'hybrid', () => setState(() => _mapType = 'hybrid')),
                    ]),
                  ),
                ]),
              ),
              // floating controls
              Positioned(
                right: 14, top: 70,
                child: Column(children: [
                  _mapCtrl(Icons.my_location, () {
                    if (_devices.isNotEmpty && _devices.first['lat'] != null) {
                      _map.move(LatLng(_toD(_devices.first['lat']), _toD(_devices.first['lng'])), 14);
                    }
                  }),
                  const SizedBox(height: 12),
                  // SHARE this vehicle's live tracking (replaces duplicate layers toggle)
                  _mapCtrl(Icons.share, () {
                    Haptics.medium();
                    final u = _selected ?? (_visibleDevices(needLatLng: true).isNotEmpty ? _visibleDevices(needLatLng: true).first : null);
                    if (u == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No vehicle to share')));
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _ShareSheet(device: u),
                    );
                  }),
                  const SizedBox(height: 12),
                  // show/hide vehicle names
                  _mapCtrl(_showNames ? Icons.label : Icons.label_off, () => setState(() => _showNames = !_showNames)),
                  const SizedBox(height: 12),
                  // reset to north (compass)
                  _mapCtrl(Icons.explore, () {
                    _map.rotate(0);
                    setState(() {});
                  }),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x1F0E5C5C), blurRadius: 8)]),
                    child: Column(children: [
                      IconButton(onPressed: () => _map.move(_map.camera.center, _map.camera.zoom + 1), icon: const Icon(Icons.add, color: AppColors.ink)),
                      Container(width: 24, height: 1, color: AppColors.line),
                      IconButton(onPressed: () => _map.move(_map.camera.center, _map.camera.zoom - 1), icon: const Icon(Icons.remove, color: AppColors.ink)),
                    ]),
                  ),
                ]),
              ),
              // ===== MINI-CARD (bottom) =====
              if (_selected != null) _miniCard(_selected!),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(Map<String, dynamic> u) {
    final s = stateOf(u['online'], u['speed']);
    final addr = (u['address'] ?? '').toString().isNotEmpty ? u['address'].toString() : '${u['lat']}, ${u['lng']}';
    final gps = s == 'of' ? 'Lost' : 'Strong';
    return Positioned(
      left: 12, right: 12, bottom: 12,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x290E5C5C), blurRadius: 24)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: const Color(0xFFD8E0DE), borderRadius: BorderRadius.circular(3)))),
          Row(children: [
            vehicleBox(u['icon_url'], box: 60, bg: stateBg(s)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: stateBg(s), borderRadius: BorderRadius.circular(20)), child: Text(stateLabels[s]!, style: TextStyle(color: stateColor(s), fontSize: 10, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.place, size: 12, color: AppColors.teal),
                const SizedBox(width: 5),
                Flexible(child: Text(addr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted))),
              ]),
            ])),
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(
                onPressed: () => _openDetail(u),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)), minimumSize: const Size(0, 0)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Text('View Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 15),
                ]),
              ),
              if (s == 'of') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _openTroubleshoot(u),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.error_outline, size: 13, color: AppColors.red),
                    SizedBox(width: 4),
                    Text('Troubleshoot', style: TextStyle(fontSize: 11.5, color: AppColors.red, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ]),
          ]),
          Container(
            margin: const EdgeInsets.only(top: 11),
            padding: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Row(children: [
              const Icon(Icons.speed, size: 14, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(s == 'of' ? '—' : '${u['speed'] ?? 0} km/h', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink2)),
              Container(width: 1, height: 13, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.line),
              const Icon(Icons.schedule, size: 14, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(agoText(u['time']), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink2)),
              Container(width: 1, height: 13, margin: const EdgeInsets.symmetric(horizontal: 10), color: AppColors.line),
              const Icon(Icons.gps_fixed, size: 14, color: AppColors.teal),
              const SizedBox(width: 5),
              RichText(text: TextSpan(style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink2), children: [
                const TextSpan(text: 'GPS '),
                TextSpan(text: gps, style: TextStyle(color: gps == 'Strong' ? AppColors.green : AppColors.red, fontWeight: FontWeight.w800)),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _segBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: active ? AppColors.teal : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }

  Widget _mapCtrl(IconData ic, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x1F0E5C5C), blurRadius: 8)]),
        child: Icon(ic, color: AppColors.teal, size: 22),
      ),
    );
  }
}

// ===== Custom vehicle marker (plate above, pic center, tag below, live pulse) =====
class _VehicleMarker extends StatelessWidget {
  final Map<String, dynamic> device;
  final String state;
  final double heading;
  final double pulse; // 0..1 from parent ticker
  final bool showName;
  final double mapRotation; // map's current rotation (deg) — used to keep labels upright
  const _VehicleMarker({required this.device, required this.state, required this.heading, required this.pulse, this.showName = true, this.mapRotation = 0});

  @override
  Widget build(BuildContext context) {
    final s = state;
    final u = device;
    final tagText = s == 'rn' ? '${u['speed'] ?? 0} km/h' : stateLabels[s]!;
    return SizedBox(
      width: 200,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // live pulse (only running)
          if (s == 'rn')
            Positioned(
              top: 32,
              child: Container(
                width: 34 * (0.5 + pulse * 1.7),
                height: 34 * (0.5 + pulse * 1.7),
                decoration: BoxDecoration(color: AppColors.green.withOpacity((1 - pulse) * 0.35), shape: BoxShape.circle),
              ),
            ),
          // plate label above (centered, full width available so it never clips)
          if (showName)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8)]),
                  child: Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
            ),
          // vehicle pic — rotated by heading, adjusted for map rotation so it
          // always points the correct way even when the map is turned
          Positioned(
            top: 28,
            child: Transform.rotate(
              angle: (heading - mapRotation) * 3.14159265 / 180.0,
              child: SizedBox(width: 46, height: 46, child: vehicleThumb(u['icon_url'], size: 46)),
            ),
          ),
          // status tag below
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(color: stateColor(s), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6)]),
                child: Text(tagText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Full vehicle detail popup (with engine cut-off) =====
class _VehicleDetailSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  final bool supportsCutoff;
  const _VehicleDetailSheet({required this.device, required this.supportsCutoff});
  @override
  State<_VehicleDetailSheet> createState() => _VehicleDetailSheetState();
}

class _VehicleDetailSheetState extends State<_VehicleDetailSheet> {
  late bool _isCut;
  bool _sending = false;
  String? _fetchedExpiry; // expiry pulled from edit_device_data when get_devices had none
  bool _loadingExpiry = false;

  @override
  void initState() {
    super.initState();
    final ts = widget.device['ts'] ?? {};
    _isCut = '${ts['blocked']}'.toLowerCase() == 'true';
    // if the live device data has no expiry, fetch it from the edit endpoint
    if ((widget.device['expiry'] == null || widget.device['expiry'].toString().isEmpty)) {
      _loadExpiry();
    }
  }

  Future<void> _loadExpiry() async {
    setState(() => _loadingExpiry = true);
    final exp = await ApiService.fetchDeviceExpiry('${widget.device['id']}');
    if (!mounted) return;
    setState(() {
      _fetchedExpiry = exp;
      _loadingExpiry = false;
    });
  }

  Future<void> _navigateTo(Map<String, dynamic> u) async {
    final lat = u['lat'], lng = u['lng'];
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No location available for this vehicle')));
      return;
    }
    // Try the Google Maps app first (geo/maps URL), then fall back to browser.
    final candidates = [
      Uri.parse('google.navigation:q=$lat,$lng'),
      Uri.parse('geo:$lat,$lng?q=$lat,$lng(Vehicle)'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving'),
    ];
    for (final url in candidates) {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No maps app found to open navigation')));
    }
  }

  Future<void> _confirmCutoff() async {
    final cut = !_isCut;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(cut ? 'Cut Off Engine?' : 'Resume Engine?'),
        content: Text(cut
            ? 'This will stop the engine of ${widget.device['name']}. Only do this when the vehicle is safely stopped.'
            : 'This will restore the engine power of ${widget.device['name']}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: cut ? AppColors.red : AppColors.green, foregroundColor: Colors.white),
            child: Text(cut ? 'Yes, Cut Off' : 'Yes, Resume'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    Haptics.heavy(); // strong feedback for this critical action
    setState(() => _sending = true);
    final success = await ApiService.sendEngineCommand('${widget.device['id']}', cut ? 'engineStop' : 'engineResume');
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (success) _isCut = cut;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? (cut ? 'Engine cut off' : 'Engine resumed') : 'Command failed')));
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.device;
    final s = stateOf(u['online'], u['speed']);
    final addr = (u['address'] ?? '').toString().isNotEmpty ? u['address'].toString() : '${u['lat']}, ${u['lng']}';
    final gps = s == 'of' ? 'Lost' : 'Strong';
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
            // head with close
            Row(children: [
              vehicleBox(u['icon_url'], box: 60, bg: stateBg(s)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: stateBg(s), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: stateColor(s), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(stateLabels[s]!, style: TextStyle(color: stateColor(s), fontSize: 10, fontWeight: FontWeight.w700)),
                  ])),
                ]),
                if ((u['model'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(u['model'], style: const TextStyle(fontSize: 12, color: AppColors.ink2))),
              ])),
              GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: AppColors.ink2))),
            ]),
            const SizedBox(height: 16),
            // 2 tiles
            Builder(builder: (_) {
              final eng = _engineState(u); // smart: real ignition, else movement-based
              return Row(children: [
                _tile('${s == 'of' ? '—' : (u['speed'] ?? 0)}', 'km/h'),
                const SizedBox(width: 9),
                _tile(eng['label'] as String, 'Engine', color: eng['color'] as Color),
              ]);
            }),
            const SizedBox(height: 14),
            // address bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.place, size: 20, color: AppColors.teal),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(addr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text('Updated ${agoText(u['time'])}', style: const TextStyle(fontSize: 11, color: AppColors.muted))),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            // vehicle details rows
            const Text('Vehicle Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink2)),
            const SizedBox(height: 6),
            _row(Icons.schedule, 'Last Update', agoText(u['time'])),
            const Divider(height: 1, color: AppColors.line),
            _row(Icons.wifi, 'GPS Signal', gps, valColor: gps == 'Strong' ? AppColors.green : AppColors.red),
            const Divider(height: 1, color: AppColors.line),
            _row(Icons.event, 'Device Expiry',
                _loadingExpiry
                    ? 'Checking…'
                    : (_expiryText(u['expiry'] ?? _fetchedExpiry) ?? 'Not set'),
                valColor: _expiryColor(u['expiry'] ?? _fetchedExpiry)),
            const SizedBox(height: 16),
            // actions: Live Track + Playback, then Reports full-width
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () { Haptics.medium(); Navigator.pop(context); },
                icon: const Icon(Icons.location_on, size: 18),
                label: const Text('Live Track'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () {
                  Haptics.medium();
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _PlaybackPicker(device: u),
                  );
                },
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Playback'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink2, side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              )),
            ]),
            const SizedBox(height: 10),
            // Navigate to vehicle via Google Maps
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Haptics.medium(); _navigateTo(u); },
                icon: const Icon(Icons.directions, size: 18),
                label: const Text('Navigate (Google Maps)'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Haptics.medium();
                  Navigator.pop(context); // close the detail sheet first
                  // switch to the Activity tab using the named route (replaces shell)
                  Navigator.pushReplacementNamed(context, '/activity');
                },
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('Reports & History'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink2, side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
              ),
            ),
            if (widget.supportsCutoff) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _isCut ? [const Color(0xFFFDF1F0), Colors.white] : [const Color(0xFFF2FBF5), Colors.white]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isCut ? const Color(0xFFF3CFCB) : const Color(0xFFCDEBD7), width: 1.5),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(width: 42, height: 42, decoration: BoxDecoration(color: _isCut ? AppColors.redBg : AppColors.greenBg, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.power_settings_new, color: _isCut ? AppColors.red : AppColors.green)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Engine Cut-Off', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(_isCut ? 'Vehicle is immobilized' : 'Immobilizer control', style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5), decoration: BoxDecoration(color: _isCut ? AppColors.red : AppColors.green, borderRadius: BorderRadius.circular(20)), child: Text(_isCut ? 'ENGINE CUT' : 'ENGINE ON', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 13),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _confirmCutoff,
                      style: ElevatedButton.styleFrom(backgroundColor: _isCut ? AppColors.green : AppColors.red, foregroundColor: Colors.white),
                      child: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isCut ? 'Resume Engine' : 'Cut Off Engine', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Smart engine on/off:
  //  1) if the ignition wire reports a value, trust it (most accurate)
  //  2) otherwise infer from movement: moving / motion = ON, else OFF
  Map<String, dynamic> _engineState(Map<String, dynamic> u) {
    final ts = (u['ts'] ?? {}) as Map;
    final ign = tBool(ts['ignition']);
    final spd = (u['speed'] is num) ? (u['speed'] as num) : (num.tryParse('${u['speed']}') ?? 0);
    final motion = tBool(ts['motion']);
    final online = (u['online'] ?? '').toString();

    if (ign != null) {
      // ignition wire connected — use the real signal
      return ign
          ? {'label': 'ON', 'color': AppColors.green}
          : {'label': 'OFF', 'color': AppColors.red};
    }
    // no ignition data — infer from movement
    if (online == 'offline') return {'label': 'OFF', 'color': AppColors.red};
    final moving = spd > 2 || motion == true;
    return moving
        ? {'label': 'ON', 'color': AppColors.green}
        : {'label': 'OFF', 'color': AppColors.red};
  }

  Widget _tile(String v, String l, {Color? color}) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Container(width: 30, height: 30, margin: const EdgeInsets.only(bottom: 6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(l == 'km/h' ? Icons.speed : Icons.power_settings_new, size: 16, color: AppColors.teal)),
            Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? AppColors.ink)),
            Text(l, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // expiry date + days to go, e.g. "2026-12-31 (188 days)"
  String? _expiryText(dynamic exp) {
    if (exp == null) return null;
    final s = exp.toString();
    if (s.isEmpty || s.startsWith('0000')) return null;
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return s;
    final days = d.difference(DateTime.now()).inDays;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    if (days < 0) return '$dateStr (expired)';
    return '$dateStr ($days day${days == 1 ? '' : 's'})';
  }

  Color _expiryColor(dynamic exp) {
    final s = exp?.toString() ?? '';
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return AppColors.ink;
    final days = d.difference(DateTime.now()).inDays;
    if (days < 0) return AppColors.red;
    if (days <= 15) return AppColors.orange;
    return AppColors.green;
  }

  Widget _row(IconData ic, String k, String v, {Color? valColor}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(ic, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          const Spacer(),
          Flexible(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valColor ?? AppColors.ink))),
        ]),
      );
}

// Quick day picker -> opens route playback for ONE specific vehicle
class _PlaybackPicker extends StatelessWidget {
  final Map<String, dynamic> device;
  const _PlaybackPicker({required this.device});

  @override
  Widget build(BuildContext context) {
    final presets = {'Today': 1, '7 Days': 7, '14 Days': 14, '30 Days': 30};
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
        Row(children: [
          const Icon(Icons.play_circle_outline, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(child: Text('Playback · ${device['name'] ?? 'Vehicle'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: AppColors.ink2))),
        ]),
        const SizedBox(height: 16),
        const Text('SELECT PERIOD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...presets.entries.map((e) {
            return GestureDetector(
              onTap: () {
                Haptics.select();
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryMapScreen(device: device, days: e.value)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E9E8), width: 1.6)),
                child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.ink)),
              ),
            );
          }),
          // Custom date range
          GestureDetector(
            onTap: () async {
              Haptics.select();
              final now = DateTime.now();
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: now,
                initialDateRange: DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.teal)),
                  child: child!,
                ),
              );
              if (range != null && context.mounted) {
                final from = DateTime(range.start.year, range.start.month, range.start.day, 0, 0, 0);
                final to = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryMapScreen(device: device, from: from, to: to)));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.teal, width: 1.6)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.date_range, size: 16, color: AppColors.teal),
                SizedBox(width: 6),
                Text('Custom Range', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ===== Share live tracking link (with expiry) via WhatsApp =====
class _ShareSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  const _ShareSheet({required this.device});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  // duration presets in hours
  static const _options = [
    {'label': '1 Hour', 'hours': 1},
    {'label': '4 Hours', 'hours': 4},
    {'label': '8 Hours', 'hours': 8},
    {'label': '1 Day', 'hours': 24},
    {'label': '3 Days', 'hours': 72},
    {'label': '1 Week', 'hours': 168},
  ];
  int _hours = 4;
  bool _creating = false;

  Future<void> _shareNow() async {
    Haptics.medium();
    setState(() => _creating = true);
    final expiresAt = DateTime.now().add(Duration(hours: _hours));
    final name = 'Shared · ${widget.device['name'] ?? 'Vehicle'}';
    final res = await ApiService.createSharing(
      devices: [int.tryParse('${widget.device['id']}') ?? 0],
      name: name,
      expiresAt: expiresAt,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (res == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not create share link. Sharing may not be enabled on your account.'),
      ));
      return;
    }
    final link = res['url'] as String;
    final validTill = _fmtExpiry(expiresAt);
    final vname = widget.device['name'] ?? 'Vehicle';
    final msg = '📍 Live location of my vehicle "$vname" via BharatGPS Tracker:\n'
        '$link\n\n'
        'Valid until $validTill. No login required.\n\n'
        '— Powered by BharatGPS 🛰\n'
        'Get yours at http://bharatgps.store';
    // open WhatsApp with the message — try app scheme, then wa.me web fallback
    final encoded = Uri.encodeComponent(msg);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final targets = [
      'whatsapp://send?text=$encoded',
      'https://wa.me/?text=$encoded',
      'https://api.whatsapp.com/send?text=$encoded',
    ];
    bool opened = false;
    for (final t in targets) {
      try {
        final uri = Uri.parse(t);
        if (await canLaunchUrl(uri)) {
          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (opened) break;
        }
      } catch (_) {}
    }
    if (!opened) {
      // last resort: copy link so the user can paste it anywhere
      await Clipboard.setData(ClipboardData(text: msg));
      messenger.showSnackBar(const SnackBar(content: Text('WhatsApp not found — message copied to clipboard')));
    }
  }

  String _fmtExpiry(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}, ${two(h)}:${two(d.minute)} $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.share, color: AppColors.teal, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Share Live Tracking', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            Text(widget.device['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
          ])),
        ]),
        const SizedBox(height: 16),
        const Text('SHARE FOR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 9, runSpacing: 9, children: _options.map((o) {
          final sel = _hours == o['hours'];
          return GestureDetector(
            onTap: () { Haptics.select(); setState(() => _hours = o['hours'] as int); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? AppColors.teal : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? AppColors.teal : AppColors.line, width: 1.3),
              ),
              child: Text(o['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.ink2)),
            ),
          );
        }).toList()),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF1F8F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD6EBE8))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('Anyone with the link can track this vehicle without login until it expires (${_fmtExpiry(DateTime.now().add(Duration(hours: _hours)))}).', style: const TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.35))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _creating ? null : _shareNow,
            icon: _creating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(_creating ? 'Creating link…' : 'Share on WhatsApp'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          ),
        ),
      ]),
    );
  }
}
