import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HistoryMapScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  final int days;
  const HistoryMapScreen({super.key, required this.device, required this.days});
  @override
  State<HistoryMapScreen> createState() => _HistoryMapScreenState();
}

class _HistoryMapScreenState extends State<HistoryMapScreen> {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _points = [];
  List<Map<String, dynamic>> _stops = [];
  double _distance = 0;
  bool _loading = true;

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
    final h = await ApiService.getHistory(deviceId: '${widget.device['id']}', days: widget.days);
    if (!mounted) return;
    setState(() {
      _points = List<Map<String, dynamic>>.from(h['points']);
      _stops = List<Map<String, dynamic>>.from(h['stops']);
      _distance = h['distance_km'];
      _loading = false;
    });
    if (_points.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = LatLngBounds.fromPoints(_points.map((p) => LatLng(p['lat'], p['lng'])).toList());
        _map.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
      });
    }
  }

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
      appBar: AppBar(
        title: Text(widget.device['name'] ?? 'Travel History'),
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: const MapOptions(initialCenter: LatLng(20.59, 78.96), initialZoom: 5),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.bharatgps.app',
                ),
                if (_points.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(points: _points.map((p) => LatLng(p['lat'], p['lng'])).toList(), color: AppColors.teal, strokeWidth: 4),
                  ]),
                MarkerLayer(markers: [
                  if (_points.isNotEmpty)
                    Marker(point: LatLng(_points.first['lat'], _points.first['lng']), width: 16, height: 16, child: Container(decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                  if (_points.isNotEmpty)
                    Marker(point: LatLng(_points.last['lat'], _points.last['lng']), width: 16, height: 16, child: Container(decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
                  ..._stops.map((s) => Marker(point: LatLng(s['lat'], s['lng']), width: 14, height: 14, child: Container(decoration: BoxDecoration(color: AppColors.orange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))))),
                  if (cur != null)
                    Marker(
                      point: LatLng(cur['lat'], cur['lng']),
                      width: 28, height: 28,
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]),
                        child: const Icon(Icons.local_shipping, color: Colors.white, size: 14),
                      ),
                    ),
                ]),
              ],
            ),
            // stats
            Positioned(
              top: 10, left: 12, right: 12,
              child: Row(children: [
                _stat('$_distance', 'KM'),
                const SizedBox(width: 8),
                _stat('${_points.length}', 'POINTS'),
                const SizedBox(width: 8),
                _stat('${_stops.length}', 'STOPS'),
              ]),
            ),
            if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.teal)),
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

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.97), borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x220E5C5C), blurRadius: 14)]),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.teal)),
            Text(l, style: const TextStyle(fontSize: 9, color: AppColors.ink2, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
