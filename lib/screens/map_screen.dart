import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  List<String> _gprsDevices = [];
  dynamic _focusId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGprs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusId ??= ModalRoute.of(context)?.settings.arguments;
  }

  Future<void> _load() async {
    final d = await ApiService.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = d;
      _loading = false;
    });
    if (_focusId != null) {
      final u = _devices.firstWhere((e) => '${e['id']}' == '$_focusId', orElse: () => {});
      if (u.isNotEmpty && u['lat'] != null) {
        _map.move(LatLng(_toD(u['lat']), _toD(u['lng'])), 15);
        WidgetsBinding.instance.addPostFrameCallback((_) => _openDetail(u));
      }
    }
  }

  Future<void> _loadGprs() async {
    final g = await ApiService.getCommandDevices();
    if (mounted) setState(() => _gprsDevices = g);
  }

  double _toD(dynamic v) => double.tryParse('$v') ?? 0;

  List<Marker> _markers() {
    return _devices.where((u) => u['lat'] != null && u['lng'] != null).map((u) {
      final s = stateOf(u['online'], u['speed']);
      return Marker(
        point: LatLng(_toD(u['lat']), _toD(u['lng'])),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _openDetail(u),
          child: Container(
            decoration: BoxDecoration(
              color: stateColor(s),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
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

  @override
  Widget build(BuildContext context) {
    final center = _devices.isNotEmpty && _devices.first['lat'] != null
        ? LatLng(_toD(_devices.first['lat']), _toD(_devices.first['lng']))
        : const LatLng(20.59, 78.96);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.teal, AppColors.teal2]),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.location_on, color: AppColors.teal, size: 22),
                ),
                const SizedBox(width: 9),
                const Text('Live Map', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white)),
              ]),
            ),
            Expanded(
              child: Stack(children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(initialCenter: center, initialZoom: _devices.isEmpty ? 5 : 12),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.bharatgps.app',
                    ),
                    MarkerLayer(markers: _markers()),
                  ],
                ),
                if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.teal)),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(current: 2),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    final ts = widget.device['ts'] ?? {};
    _isCut = '${ts['blocked']}'.toLowerCase() == 'true';
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
    setState(() => _sending = true);
    final success = await ApiService.sendEngineCommand('${widget.device['id']}', cut ? 'engineStop' : 'engineResume');
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (success) _isCut = cut;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? (cut ? 'Engine cut off' : 'Engine resumed') : 'Command failed'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.device;
    final s = stateOf(u['online'], u['speed']);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
            Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)), child: Center(child: vehicleThumb(u['icon_url'], size: 48))),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] ?? 'Vehicle', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                if ((u['model'] ?? '').toString().isNotEmpty)
                  Text(u['model'], style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: stateBg(s), borderRadius: BorderRadius.circular(20)),
                child: Text(stateLabels[s]!, style: TextStyle(color: stateColor(s), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _tile('${s == 'of' ? '—' : (u['speed'] ?? 0)}', 'km/h'),
              const SizedBox(width: 9),
              _tile(s == 'rn' ? 'ON' : (s == 'id' ? 'IDLE' : 'OFF'), 'Engine'),
            ]),
            const SizedBox(height: 14),
            _row(Icons.schedule, 'Last Update', agoText(u['time'])),
            _row(Icons.my_location, 'Location', (u['address'] ?? '').toString().isNotEmpty ? u['address'] : '${u['lat']}, ${u['lng']}'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.location_on, size: 18),
                label: const Text('Live Track'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
              const SizedBox(width: 11),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/activity'),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('Reports'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(vertical: 13)),
              )),
            ]),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(color: _isCut ? AppColors.red : AppColors.green, borderRadius: BorderRadius.circular(20)),
                      child: Text(_isCut ? 'ENGINE CUT' : 'ENGINE ON', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
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

  Widget _tile(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(l, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _row(IconData ic, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(ic, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          const Spacer(),
          Flexible(child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );
}
