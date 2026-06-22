import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/loaders.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    if (ApiService.cachedDevices.isNotEmpty) {
      _devices = ApiService.cachedDevices;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = d;
        _loading = false;
      });
      _resolveAddresses(d);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveAddresses(List<Map<String, dynamic>> devs) async {
    for (final u in devs) {
      if ((u['address'] ?? '').toString().isNotEmpty) continue;
      if (u['lat'] == null || u['lng'] == null) continue;
      final name = await ApiService.reverseGeocode(u['lat'], u['lng']);
      if (name != null && mounted) setState(() => u['address'] = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _devices.length;
    int run = 0, idle = 0, off = 0;
    for (final u in _devices) {
      final s = stateOf(u['online'], u['speed']);
      if (s == 'rn') run++;
      else if (s == 'id') idle++;
      else off++;
    }
    String pct(int n) => total == 0 ? '0%' : '${((n / total) * 100).round()}%';

    var list = _devices.where((u) {
      if (_filter.isEmpty) return true;
      return stateOf(u['online'], u['speed']) == _filter;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          // ===== HEADER =====
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.teal2]),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.all(3), child: Image.asset('assets/logo-icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.location_on, color: AppColors.teal, size: 22))),
                    const SizedBox(width: 9),
                    const Text('Bharat GPS Tracker', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pushReplacementNamed(context, '/alerts'), icon: const Icon(Icons.notifications_none, color: Colors.white, size: 23)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
                      child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: AppColors.teal, size: 22)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
                const Text('Welcome back 👋', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          // ===== STATS =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              _stat('Total', total, 'All vehicles', AppColors.teal, Icons.local_shipping, ''),
              const SizedBox(width: 9),
              _stat('Running', run, pct(run), AppColors.green, Icons.play_arrow, 'rn'),
              const SizedBox(width: 9),
              _stat('Idle', idle, pct(idle), AppColors.orange, Icons.pause, 'id'),
              const SizedBox(width: 9),
              _stat('Offline', off, pct(off), AppColors.red, Icons.stop, 'of'),
            ]),
          ),
          // ===== My Vehicles + Live =====
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(children: [
              const Text('My Vehicles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Live', style: TextStyle(color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
          // ===== LIST =====
          Expanded(
            child: _loading
                ? const SignalLoader(label: 'Loading your fleet…')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _vehicleCard(list[i]),
                    ),
                  ),
          ),
          // ===== Track banner =====
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/map'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.teal2]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                const Icon(Icons.map_outlined, color: Colors.white, size: 40),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Text('Track Anytime, Anywhere', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Live location of all your vehicles in real-time.', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Text('Track', style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(width: 5),
                    Icon(Icons.arrow_forward, color: AppColors.teal, size: 15),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(current: 0),
    );
  }

  Widget _stat(String label, int val, String sub, Color color, IconData ic, String filterKey) {
    final active = _filter == filterKey && filterKey.isNotEmpty;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = (_filter == filterKey) ? '' : filterKey),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: active ? Border.all(color: AppColors.teal, width: 2) : null,
            boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 8)],
          ),
          child: Column(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(ic, color: Colors.white, size: 17)),
            const SizedBox(height: 7),
            Text('$val', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.ink2, fontWeight: FontWeight.w600, height: 1.2)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> u) {
    final s = stateOf(u['online'], u['speed']);
    final spd = s == 'of' ? '—' : '${u['speed'] ?? 0} km/h';
    final tint = s == 'rn'
        ? [const Color(0xFFF2FBF5), Colors.white]
        : (s == 'id' ? [const Color(0xFFFEF8EE), Colors.white] : [const Color(0xFFFDF1F0), Colors.white]);
    final addr = (u['address'] ?? '').toString().isNotEmpty ? u['address'].toString() : 'Locating…';
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/map', arguments: u['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 12, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            Row(children: [
              vehicleBox(u['icon_url'], box: 50, bg: stateBg(s)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if ((u['model'] ?? '').toString().isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(u['model'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2))),
              ])),
              Container(
                width: 11, height: 11,
                decoration: BoxDecoration(color: stateColor(s), shape: BoxShape.circle, boxShadow: [BoxShadow(color: stateBg(s), blurRadius: 0, spreadRadius: 4)]),
              ),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x0D000000)))),
              child: Row(children: [
                const Icon(Icons.speed, size: 13, color: AppColors.teal),
                const SizedBox(width: 4),
                Text(spd, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(width: 12),
                const Icon(Icons.place, size: 13, color: AppColors.teal),
                const SizedBox(width: 4),
                Expanded(child: Text(addr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink2))),
                const SizedBox(width: 8),
                const Icon(Icons.access_time, size: 13, color: AppColors.teal),
                const SizedBox(width: 4),
                Text(agoText(u['time']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink2)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaCol(String label, IconData ic, String value, CrossAxisAlignment align, TextAlign ta) {
    return Expanded(
      child: Column(crossAxisAlignment: align, children: [
        Text(label, style: const TextStyle(fontSize: 8.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: align == CrossAxisAlignment.start ? MainAxisAlignment.start : (align == CrossAxisAlignment.end ? MainAxisAlignment.end : MainAxisAlignment.center), children: [
          Icon(ic, size: 12, color: AppColors.teal),
          const SizedBox(width: 4),
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: ta, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink))),
        ]),
      ]),
    );
  }
}
