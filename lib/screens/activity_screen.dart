import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'tour_keys.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import 'history_map_screen.dart';
import 'trips_screen.dart';
import '../widgets/loaders.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  final Map<String, Map<String, dynamic>> _stats = {};
  final Set<String> _loadingStats = {};
  double _fleetKm = 0;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    if (ApiService.cachedDevices.isNotEmpty) {
      _devices = [...ApiService.cachedDevices]..sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
      _loading = false;
    }
    _load();
    // keep fleet activity live, matching the map's 5s refresh
    _refresh = Timer.periodic(const Duration(seconds: 10), (_) {
      if (MainShell.currentTab.value == 1) _load();
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await ApiService.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = d
        ..sort((a, b) => '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()));
      _loading = false;
    });
  }

  Future<void> _loadStats(Map<String, dynamic> u) async {
    final id = '${u['id']}';
    if (_stats.containsKey(id) || _loadingStats.contains(id)) return;
    setState(() => _loadingStats.add(id));
    final st = await ApiService.getDayStats(id);
    if (!mounted) return;
    setState(() {
      _stats[id] = st;
      _loadingStats.remove(id);
      _fleetKm += (st['distance_today'] is num) ? st['distance_today'] : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    int moving = 0, active = 0, idle = 0, offline = 0;
    for (final u in _devices) {
      final s = stableStateFor('${u['id']}', u['online'], u['speed']);
      if (s == 'rn') moving++;
      if (s == 'id') idle++;
      if (s == 'of') offline++;
      if (s != 'of') active++;
    }
    return Scaffold(
      body: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.teal, AppColors.teal2]),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.all(3), child: Image.asset('assets/logo-icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.location_on, color: AppColors.teal, size: 20))),
                const SizedBox(width: 9),
                const Text('Bharat GPS Tracker', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              const Text('Fleet Activity', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              Text('Reports, insights & travel history', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
            ]),
          ),
          Expanded(
            child: _loading
                ? const SpeedoLoader()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    children: [
                      // Fleet status breakdown (running / idle / offline at a glance)
                      Container(
                        key: TourKeys.activityStatus,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
                        child: Column(children: [
                          Row(children: [
                            const Text('Fleet Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text('${_devices.length} vehicles', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                          const SizedBox(height: 12),
                          // status bar (proportional)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Row(children: [
                              if (moving > 0) Expanded(flex: moving, child: Container(height: 10, color: AppColors.green)),
                              if (idle > 0) Expanded(flex: idle, child: Container(height: 10, color: AppColors.orange)),
                              if (offline > 0) Expanded(flex: offline, child: Container(height: 10, color: AppColors.red)),
                              if (_devices.isEmpty) Expanded(child: Container(height: 10, color: AppColors.line)),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _legend(AppColors.green, 'Running', moving),
                            _legend(AppColors.orange, 'Idle', idle),
                            _legend(AppColors.red, 'Offline', offline),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // insights row: fleet distance today + needs attention
                      Row(children: [
                        _fleet('${_fleetKm.round()}', 'km', 'Fleet Distance Today', AppColors.blue, AppColors.blueBg, Icons.show_chart),
                        const SizedBox(width: 10),
                        _fleet('$offline', '', offline == 0 ? 'All Online' : 'Need Attention', offline == 0 ? AppColors.green : AppColors.red, offline == 0 ? AppColors.greenBg : AppColors.redBg, offline == 0 ? Icons.check_circle : Icons.warning_amber),
                      ]),
                      const SizedBox(height: 18),
                      const Text('VEHICLE REPORTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      ..._devices.map(_reportCard),
                    ],
                  ),
          ),
        ]),
    );
  }

  Widget _legend(Color c, String label, int count) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ]);

  Widget _fleet(String v, String unit, String label, Color color, Color bg, IconData ic) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(ic, color: color, size: 20)),
            const SizedBox(height: 9),
            RichText(text: TextSpan(children: [
              TextSpan(text: v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
              if (unit.isNotEmpty) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
            ])),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
          ]),
        ),
      );

  Widget _reportCard(Map<String, dynamic> u) {
    final id = '${u['id']}';
    final s = stableStateFor('${u['id']}', u['online'], u['speed']);
    final st = _stats[id];
    final loadingThis = _loadingStats.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
      child: Column(children: [
        Row(children: [
          vehicleBox(u['icon_url'], box: 46, bg: stateBg(s)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            Text((u['model'] ?? 'GPS Device').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: stateBg(s), borderRadius: BorderRadius.circular(20)), child: Text(stateLabels[s]!, style: TextStyle(color: stateColor(s), fontSize: 9.5, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        if (st != null)
          Row(children: [
            _rs('${st['distance_today']}', 'KM TODAY'),
            _rs('${st['hours_today']}', 'HRS'),
            _rs('${st['max_speed_today']}', 'MAX KM/H'),
            _rs(s == 'of' ? '—' : '${u['speed'] ?? 0}', 'NOW KM/H'),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: loadingThis ? null : () { Haptics.light(); _loadStats(u); },
              icon: loadingThis
                  ? const RouteMiniLoader(width: 28, height: 14)
                  : const Icon(Icons.show_chart, size: 15),
              label: Text(loadingThis ? 'Loading…' : 'Load today\u2019s stats'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.teal, side: const BorderSide(color: Color(0xFFDCEBE9))),
            ),
          ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 11), child: Divider(height: 1)),
        Row(children: [
          const Icon(Icons.schedule, size: 13, color: AppColors.teal),
          const SizedBox(width: 5),
          Text(agoText(u['time']), style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TripsScreen(device: u))),
            child: const Row(children: [
              Icon(Icons.route, size: 14, color: AppColors.violet),
              SizedBox(width: 4),
              Text('Trips', style: TextStyle(fontSize: 11, color: AppColors.violet, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => _openHistory(u),
            child: const Row(children: [
              Text('View Report', style: TextStyle(fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward, size: 14, color: AppColors.teal),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _rs(String v, String l) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(11)),
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.teal)),
            Text(l, style: const TextStyle(fontSize: 9, color: AppColors.ink2, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  void _openHistory(Map<String, dynamic> u) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(device: u),
    );
  }
}

class _HistorySheet extends StatefulWidget {
  final Map<String, dynamic> device;
  const _HistorySheet({required this.device});
  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  int _days = 1;
  final _presets = {'Today': 1, '7 Days': 7, '14 Days': 14, '30 Days': 30};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
        Row(children: [
          Expanded(child: Text(widget.device['name'] ?? 'Vehicle', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        const SizedBox(height: 8),
        const Text('QUICK SELECT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _presets.entries.map((e) {
          final sel = _days == e.value;
          return GestureDetector(
            onTap: () => setState(() => _days = e.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFF1F8F7) : Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: sel ? AppColors.teal : const Color(0xFFE2E9E8), width: 1.6),
              ),
              child: Text(e.key, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: sel ? AppColors.teal : AppColors.ink)),
            ),
          );
        }).toList()),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryMapScreen(device: widget.device, days: _days)));
            },
            icon: const Icon(Icons.map),
            label: const Text('View on Map'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
    );
  }
}
