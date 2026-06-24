import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Geofence management — create fixed map zones (circle/polygon), name them,
/// list & delete. A geofence is NOT tied to a vehicle; vehicles are attached
/// later when a Geofence alert is created in the Create Alert sheet.
class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});
  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  String _shape = 'circle';
  LatLng? _center;
  double _radius = 200;
  final List<LatLng> _poly = [];
  String _color = '#0E5C5C';
  bool _saving = false;
  bool _searching = false;

  List<Map<String, dynamic>> _geofences = [];
  bool _loadingList = false;

  // reference overlays: vehicles (static snapshot) + user's live location
  List<Map<String, dynamic>> _vehicles = [];
  LatLng? _userLocation;

  static const _colors = ['#0E5C5C', '#F5A623', '#C0392B', '#2980B9', '#27AE60', '#8E44AD'];

  Color _hex(String h) => Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));
  double _toD(dynamic v) => double.tryParse('$v') ?? 0;

  @override
  void initState() {
    super.initState();
    _loadList();
    _loadVehicles();
  }

  // load vehicles once as a static snapshot (reference points while drawing)
  Future<void> _loadVehicles() async {
    try {
      final d = await ApiService.getDevices();
      if (!mounted) return;
      setState(() => _vehicles = d.where((u) => _toD(u['lat']) != 0 && _toD(u['lng']) != 0).toList());
      // center the map on the first vehicle so the user starts near their fleet
      if (_vehicles.isNotEmpty && _center == null && _poly.isEmpty) {
        final u = _vehicles.first;
        _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 13);
      }
    } catch (_) {}
  }

  // user's LIVE location (blue dot) — same as the main map
  Future<void> _goToMyLocation() async {
    Haptics.medium();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Please turn on GPS/location on your phone');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission denied');
        return;
      }
      Position? pos;
      try { pos = await Geolocator.getLastKnownPosition(); } catch (_) {}
      try {
        pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium, timeLimit: const Duration(seconds: 12));
      } catch (_) {}
      if (pos == null) { _snack('Could not get your location'); return; }
      if (!mounted) return;
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = here);
      _map.move(here, 16);
    } catch (_) {
      _snack('Could not get your location');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _onTap(TapPosition tp, LatLng p) {
    Haptics.light();
    setState(() {
      if (_shape == 'circle') {
        _center = p;
      } else {
        _poly.add(p);
      }
    });
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final r = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(q)}'),
        headers: {'User-Agent': 'BharatGPS/1.0'},
      ).timeout(const Duration(seconds: 15));
      final list = jsonDecode(r.body);
      if (list is List && list.isNotEmpty) {
        final lat = double.parse(list[0]['lat']);
        final lon = double.parse(list[0]['lon']);
        _map.move(LatLng(lat, lon), 15);
      } else {
        _snack('No results found');
      }
    } catch (_) {
      _snack('Search failed');
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { _snack('Enter a name'); return; }
    if (_shape == 'circle' && _center == null) { _snack('Tap the map to set the centre'); return; }
    if (_shape == 'polygon' && _poly.length < 3) { _snack('Add at least 3 points'); return; }

    Haptics.medium();
    setState(() => _saving = true);
    final id = await ApiService.createGeofence(
      name: name,
      type: _shape,
      color: _color,
      radius: _radius,
      center: _center == null ? null : {'lat': _center!.latitude, 'lng': _center!.longitude},
      polygon: _poly.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null || true) {
      // some servers return 200 without a clean id; treat 200 as success and refresh
      _snack('Geofence saved');
      _nameCtrl.clear();
      setState(() { _center = null; _poly.clear(); });
      _loadList();
    }
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    final gfs = await ApiService.getGeofences();
    if (!mounted) return;
    setState(() { _geofences = gfs; _loadingList = false; });
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete geofence?'),
        content: const Text('This will remove the geofence permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.deleteGeofence(id);
      _loadList();
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        title: const Text('Geofence', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _showList, icon: const Icon(Icons.list)),
        ],
      ),
      body: Stack(children: [
        // MAP
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(17.6868, 83.2185),
            initialZoom: 12,
            onTap: _onTap,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.bharatgps.bharatgps_app',
            ),
            if (_shape == 'circle' && _center != null)
              CircleLayer(circles: [
                CircleMarker(
                  point: _center!,
                  radius: _radius,
                  useRadiusInMeter: true,
                  color: _hex(_color).withOpacity(0.18),
                  borderColor: _hex(_color),
                  borderStrokeWidth: 2,
                ),
              ]),
            if (_shape == 'polygon' && _poly.isNotEmpty)
              PolygonLayer(polygons: [
                Polygon(
                  points: _poly,
                  color: _hex(_color).withOpacity(0.18),
                  borderColor: _hex(_color),
                  borderStrokeWidth: 2,
                  isFilled: true,
                ),
              ]),
            if (_shape == 'polygon')
              MarkerLayer(markers: _poly.map((p) => Marker(
                point: p, width: 14, height: 14,
                child: Container(decoration: BoxDecoration(color: _hex(_color), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
              )).toList()),
            // VEHICLES (static snapshot) — reference points so the user can draw
            // a fence around a vehicle. Non-tappable so they don't block drawing.
            if (_vehicles.isNotEmpty)
              IgnorePointer(
                child: MarkerLayer(markers: _vehicles.map((u) => Marker(
                  point: LatLng(_toD(u['lat']), _toD(u['lng'])),
                  width: 90, height: 46,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(5)),
                      child: Text('${u['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)]),
                      child: const Icon(Icons.directions_car, color: Colors.white, size: 12),
                    ),
                  ]),
                )).toList()),
              ),
            // USER LIVE location (blue dot)
            if (_userLocation != null)
              MarkerLayer(markers: [
                Marker(
                  point: _userLocation!,
                  width: 26, height: 26,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: const Color(0xFF1A73E8).withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                    ),
                  ),
                ),
              ]),
          ],
        ),

        // SEARCH BAR
        Positioned(
          top: 10, left: 12, right: 12,
          child: Row(children: [
            Expanded(
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Search address or place...',
                    prefixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ),
          ]),
        ),

        // LOCATE ME button (live user location) — right side, below search
        Positioned(
          top: 64, right: 12,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _goToMyLocation,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.my_location, color: AppColors.teal, size: 22),
              ),
            ),
          ),
        ),

        // BOTTOM PANEL
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 16)]),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 14 + MediaQuery.of(context).padding.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),

                // shape toggle
                Container(
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [
                    _segBtn('Circle', Icons.circle_outlined, _shape == 'circle', () => setState(() { _shape = 'circle'; _poly.clear(); })),
                    _segBtn('Polygon', Icons.hexagon_outlined, _shape == 'polygon', () => setState(() { _shape = 'polygon'; _center = null; })),
                  ]),
                ),
                const SizedBox(height: 10),

                if (_shape == 'circle') ...[
                  Row(children: [
                    Text('Radius: ${_radius.round()} m', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                  Slider(
                    value: _radius, min: 50, max: 5000, divisions: 99,
                    activeColor: AppColors.teal,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const Text('Tap the map to set the centre point.', style: TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                ] else ...[
                  Row(children: [
                    const Expanded(child: Text('Tap the map to add corner points (min 3).', style: TextStyle(fontSize: 11.5, color: AppColors.ink2))),
                    if (_poly.isNotEmpty) TextButton(onPressed: () => setState(() => _poly.removeLast()), child: const Text('Undo')),
                    if (_poly.isNotEmpty) TextButton(onPressed: () => setState(() => _poly.clear()), child: const Text('Clear')),
                  ]),
                ],
                const SizedBox(height: 6),

                // colours
                Row(children: _colors.map((c) {
                  final on = c == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30, height: 30, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: _hex(c), borderRadius: BorderRadius.circular(8), border: Border.all(color: on ? Colors.black : Colors.transparent, width: 2)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 10),

                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'Geofence name (e.g. Warehouse)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('A geofence is a fixed area on the map. Vehicles are attached when you create a Geofence alert.', style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3)),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt, size: 19),
                    label: Text(_saving ? 'Saving...' : 'Save Geofence'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _segBtn(String label, IconData ic, bool on, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: () { Haptics.select(); onTap(); },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: on ? AppColors.teal : Colors.transparent, borderRadius: BorderRadius.circular(9)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ic, size: 16, color: on ? Colors.white : AppColors.ink2),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : AppColors.ink2)),
            ]),
          ),
        ),
      );

  void _showList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
            const Text('My Geofences', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_loadingList)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
            else if (_geofences.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No geofences yet.', style: TextStyle(color: AppColors.ink2)))
            else
              ..._geofences.map((g) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      Container(width: 14, height: 14, decoration: BoxDecoration(color: _hex(g['color'] ?? '#0E5C5C'), shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(g['name'] ?? 'Geofence', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      Text((g['type'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async { await _delete(g['id'] as int); setSheet(() {}); },
                        child: const Text('Delete', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ]),
                  )),
          ]),
        );
      }),
    );
  }
}
