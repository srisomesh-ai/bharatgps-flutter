import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/loaders.dart';
import '../widgets/bottom_nav.dart';

class HistoryMapScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final int days;
  final DateTime? from;
  final DateTime? to;
  const HistoryMapScreen({super.key, required this.device, this.days = 1, this.from, this.to});
  @override
  State<HistoryMapScreen> createState() => _HistoryMapScreenState();
}

class _HistoryMapScreenState extends State<HistoryMapScreen> {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _points = [];
  List<Map<String, dynamic>> _stops = [];
  double _distance = 0;
  bool _loading = true;
  bool _showArrows = true; // direction arrows on the route

  // summary stats from history
  int _maxSpeed = 0;
  int _movingSecs = 0;
  int _totalSecs = 0;

  int _idx = 0;
  bool _playing = false;
  Timer? _timer;
  int _speed = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final h = (widget.from != null && widget.to != null)
        ? await ApiService.getHistory(deviceId: '${widget.device['id']}', from: widget.from, to: widget.to)
        : await ApiService.getHistory(deviceId: '${widget.device['id']}', days: widget.days);
    if (!mounted) return;
    setState(() {
      _points = List<Map<String, dynamic>>.from(h['points']);
      _stops = List<Map<String, dynamic>>.from(h['stops']);
      _distance = h['distance_km'];
      _maxSpeed = (h['max_speed'] ?? 0) as int;
      _movingSecs = (h['moving_secs'] ?? 0) as int;
      _totalSecs = (h['total_secs'] ?? 0) as int;
      _loading = false;
    });
    if (_points.isNotEmpty) {
      // small delay lets the map controller attach so tiles load at the right
      // zoom immediately (fixes the blurry map that only sharpens after a tap)
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        try {
          final bounds = LatLngBounds.fromPoints(_points.map((p) => LatLng(p['lat'], p['lng'])).toList());
          _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
        } catch (_) {}
      });
    }
  }

  // build direction-arrow markers along the route (every Nth point)
  List<Marker> _arrowMarkers() {
    if (!_showArrows || _points.length < 2) return [];
    final markers = <Marker>[];
    // place ~14 arrows spread across the route
    final step = (_points.length / 14).ceil().clamp(1, _points.length);
    for (int i = step; i < _points.length - 1; i += step) {
      final a = _points[i];
      final b = _points[i + 1];
      final brng = _bearing(a, b);
      // skip arrows where the vehicle was basically stopped
      if ((a['spd'] as int? ?? 0) <= 2) continue;
      markers.add(Marker(
        point: LatLng(a['lat'], a['lng']),
        width: 22, height: 22,
        child: Transform.rotate(
          angle: brng * 3.14159265 / 180.0,
          child: const Icon(Icons.navigation, color: AppColors.teal, size: 18),
        ),
      ));
    }
    return markers;
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '—';
    final dt = DateTime.tryParse(t.toString().replaceFirst(' ', 'T'));
    if (dt == null) return t.toString();
    return DateFormat('dd MMM, hh:mm a').format(dt);
  }

  String _fmtDur(int secs) {
    if (secs <= 0) return '—';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  void _showStopInfo(Map<String, dynamic> s) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.pause_circle_filled, color: AppColors.orange, size: 23)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vehicle Stop', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              Text('Parked / idle for ${_fmtDur(s['secs'] as int? ?? 0)}', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
            ]),
          ]),
          const SizedBox(height: 18),
          _stopRow(Icons.login, 'Arrived', _fmtTime(s['arrived']), AppColors.green),
          const SizedBox(height: 12),
          _stopRow(Icons.logout, 'Departed', _fmtTime(s['departed']), AppColors.red),
          const SizedBox(height: 12),
          _stopRow(Icons.timelapse, 'Duration', _fmtDur(s['secs'] as int? ?? 0), AppColors.teal),
          const SizedBox(height: 12),
          _stopRow(Icons.place, 'Location', '${(s['lat'] as num).toStringAsFixed(5)}, ${(s['lng'] as num).toStringAsFixed(5)}', AppColors.blue),
        ]),
      ),
    );
  }

  Widget _stopRow(IconData ic, String label, String val, Color color) => Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)), child: Icon(ic, size: 17, color: color)),
        const SizedBox(width: 12),
        SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2, fontWeight: FontWeight.w600))),
        Expanded(child: Text(val, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
      ]);

  void _play() {
    if (_idx >= _points.length - 1) _idx = 0;
    setState(() => _playing = true);
    _timer = Timer.periodic(Duration(milliseconds: 220 ~/ _speed), (t) {
      if (_idx >= _points.length - 1) {
        _pause();
        return;
      }
      setState(() => _idx++);
      _map.move(LatLng(_points[_idx]['lat'], _points[_idx]['lng']), _map.camera.zoom);
    });
  }

  void _pause() {
    _timer?.cancel();
    if (mounted) setState(() => _playing = false);
  }

  String _clock(dynamic t) {
    final d = DateTime.tryParse(t.toString().replaceFirst(' ', 'T'));
    return d != null ? DateFormat('hh:mm a').format(d) : '—';
  }

  @override
  Widget build(BuildContext context) {
    final cur = _points.isNotEmpty ? _points[_idx] : null;
    return Scaffold(
      body: Column(children: [
        // teal header (full cover, matches other screens)
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.teal2])),
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 14),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Route Playback', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              Text(widget.device['name'] ?? 'Travel History', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: const MapOptions(initialCenter: LatLng(20.59, 78.96), initialZoom: 5),
              children: [
                TileLayer(
                  urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=en',
                  subdomains: const ['0', '1', '2', '3'],
                  userAgentPackageName: 'com.bharatgps.app',
                  maxZoom: 20,
                ),
                if (_points.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(points: _points.map((p) => LatLng(p['lat'], p['lng'])).toList(), color: AppColors.teal, strokeWidth: 4),
                  ]),
                // direction arrows along the route (toggle)
                if (_showArrows) MarkerLayer(markers: _arrowMarkers()),
                MarkerLayer(markers: [
                  // START (green) with label
                  if (_points.isNotEmpty)
                    Marker(
                      point: LatLng(_points.first['lat'], _points.first['lng']),
                      width: 80, height: 56,
                      child: _labeledPin('START', AppColors.green, Icons.flag),
                    ),
                  // STOPS (orange) — tappable for arrival/departure details
                  ..._stops.map((s) => Marker(
                        point: LatLng(s['lat'], s['lng']),
                        width: 96, height: 52,
                        child: GestureDetector(
                          onTap: () => _showStopInfo(s),
                          child: _labeledPin('${s['mins'] ?? ''}m stop', AppColors.orange, Icons.pause),
                        ),
                      )),
                  // END (red) with label
                  if (_points.length > 1)
                    Marker(
                      point: LatLng(_points.last['lat'], _points.last['lng']),
                      width: 80, height: 56,
                      child: _labeledPin('END', AppColors.red, Icons.stop),
                    ),
                  // MOVING marker = the vehicle's own icon (transparent PNG, rotated to heading)
                  if (cur != null)
                    Marker(
                      point: LatLng(cur['lat'], cur['lng']),
                      width: 54, height: 54,
                      child: Transform.rotate(
                        angle: _headingAt(_idx) * 3.14159265 / 180.0,
                        child: vehicleThumb(widget.device['icon_url'], size: 48),
                      ),
                    ),
                ]),
              ],
            ),
            // stats: Distance · Max Speed · Stops · Duration
            Positioned(
              top: 10, left: 12, right: 12,
              child: Row(children: [
                _stat('$_distance', 'KM'),
                const SizedBox(width: 8),
                _stat('$_maxSpeed', 'MAX km/h'),
                const SizedBox(width: 8),
                _stat('${_stops.length}', 'STOPS'),
                const SizedBox(width: 8),
                _stat(_fmtDur(_movingSecs), 'MOVING'),
              ]),
            ),
            // direction-arrow toggle button
            if (_points.length > 1)
              Positioned(
                top: 64, right: 12,
                child: GestureDetector(
                  onTap: () { Haptics.select(); setState(() => _showArrows = !_showArrows); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _showArrows ? AppColors.teal : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.navigation, size: 16, color: _showArrows ? Colors.white : AppColors.teal),
                      const SizedBox(width: 5),
                      Text('Direction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _showArrows ? Colors.white : AppColors.teal)),
                    ]),
                  ),
                ),
              ),
            if (_loading)
              Container(
                color: Colors.white.withOpacity(0.82),
                child: const Center(child: RouteLoader(label: 'Loading route…')),
              ),
            if (!_loading && _points.isEmpty)
              const Center(child: Text('No route data for this period', style: TextStyle(color: AppColors.ink2))),
          ]),
        ),
        // playback bar
        if (_points.isNotEmpty)
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            child: Row(children: [
              GestureDetector(
                onTap: () => _playing ? _pause() : _play(),
                child: Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                  child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(children: [
                Slider(
                  value: _idx.toDouble(),
                  min: 0,
                  max: (_points.length - 1).toDouble(),
                  activeColor: AppColors.teal,
                  onChanged: (v) {
                    _pause();
                    setState(() => _idx = v.round());
                    _map.move(LatLng(_points[_idx]['lat'], _points[_idx]['lng']), _map.camera.zoom);
                  },
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_clock(cur?['t'])} · ${cur?['spd'] ?? 0} km/h', style: const TextStyle(fontSize: 10.5, color: AppColors.ink2, fontWeight: FontWeight.w600)),
                  Text(_clock(_points.last['t']), style: const TextStyle(fontSize: 10.5, color: AppColors.ink2, fontWeight: FontWeight.w600)),
                ]),
              ])),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _speed = _speed == 8 ? 1 : _speed * 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
                  child: Text('${_speed}x', style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  // heading for the marker at index i: use course if present, else bearing to next point
  double _headingAt(int i) {
    if (_points.isEmpty) return 0;
    final c = (_points[i]['course'] is num) ? (_points[i]['course'] as num).toDouble() : 0.0;
    if (c != 0) return c;
    // bearing from this point to the next one
    final j = (i + 1 < _points.length) ? i + 1 : i;
    if (j == i && i > 0) {
      // last point: use bearing from previous
      return _bearing(_points[i - 1], _points[i]);
    }
    return _bearing(_points[i], _points[j]);
  }

  double _bearing(Map a, Map b) {
    final lat1 = (a['lat'] as num).toDouble() * 3.14159265 / 180;
    final lat2 = (b['lat'] as num).toDouble() * 3.14159265 / 180;
    final dLon = ((b['lng'] as num).toDouble() - (a['lng'] as num).toDouble()) * 3.14159265 / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = math.atan2(y, x) * 180 / 3.14159265;
    return (brng + 360) % 360;
  }

  Widget _labeledPin(String label, Color color, IconData ic) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
      ),
      Container(
        margin: const EdgeInsets.only(top: 2),
        width: 22, height: 22,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)]),
        child: Icon(ic, color: Colors.white, size: 12),
      ),
    ]);
  }

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x220E5C5C), blurRadius: 14)]),
          child: Column(children: [
            FittedBox(child: Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.teal))),
            const SizedBox(height: 1),
            FittedBox(child: Text(l, style: const TextStyle(fontSize: 8.5, color: AppColors.ink2, fontWeight: FontWeight.w700))),
          ]),
        ),
      );
}
