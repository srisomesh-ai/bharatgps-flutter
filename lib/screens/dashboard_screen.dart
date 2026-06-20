import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String _filter = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
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
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    var list = _devices.where((u) {
      if (_search.isNotEmpty && !(u['name'] ?? '').toString().toLowerCase().contains(_search)) return false;
      if (_filter.isEmpty) return true;
      return stateOf(u['online'], u['speed']) == _filter;
    }).toList()
      ..sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.teal, AppColors.teal2]),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.location_on, color: AppColors.teal, size: 22),
                    ),
                    const SizedBox(width: 9),
                    const Text('Bharat GPS Tracker', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 12),
                  Text('Welcome back', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  const Text('Your Fleet', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            // stats
            Container(
              color: AppColors.bg,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                _stat('Total', total, AppColors.blue, ''),
                _stat('Running', run, AppColors.green, 'rn'),
                _stat('Idle', idle, AppColors.orange, 'id'),
                _stat('Offline', off, AppColors.red, 'of'),
              ]),
            ),
            // search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search vehicles…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            // list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _vehicleCard(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(current: 0),
    );
  }

  Widget _stat(String label, int val, Color color, String filterKey) {
    final active = _filter == filterKey && filterKey.isNotEmpty;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = (_filter == filterKey) ? '' : filterKey),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: color, width: 1.5) : null,
            boxShadow: const [BoxShadow(color: Color(0x110E5C5C), blurRadius: 8)],
          ),
          child: Column(children: [
            Text('$val', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.ink2, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _vehicleCard(Map<String, dynamic> u) {
    final s = stateOf(u['online'], u['speed']);
    final spd = s == 'of' ? '—' : '${u['speed'] ?? 0} km/h';
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/map', arguments: u['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [stateBg(s).withOpacity(0.5), Colors.white]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Center(child: vehicleThumb(u['icon_url'])),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u['name'] ?? 'Vehicle',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if ((u['model'] ?? '').toString().isNotEmpty)
                    Text(u['model'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                ]),
              ),
              Container(width: 11, height: 11, decoration: BoxDecoration(color: stateColor(s), shape: BoxShape.circle)),
            ]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
            Row(children: [
              const Icon(Icons.speed, size: 13, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(spd, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.ink2)),
              const Spacer(),
              const Icon(Icons.schedule, size: 13, color: AppColors.teal),
              const SizedBox(width: 5),
              Text(agoText(u['time']), style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
            ]),
          ],
        ),
      ),
    );
  }
}
