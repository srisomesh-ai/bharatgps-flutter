import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _devices = [];
  final Map<String, String> _names = {};
  bool _loadingAlerts = true;
  bool _loadingEvents = false;
  bool _eventsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && !_eventsLoaded) _loadEvents();
    });
    _loadVehicles();
    _loadAlerts();
  }

  Future<void> _loadVehicles() async {
    final d = await ApiService.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = d;
      for (final u in d) {
        final nm = u['name'] ?? 'Device ${u['id']}';
        _names['${u['id']}'] = nm;
        if (u['traccar_id'] != null) _names['${u['traccar_id']}'] = nm; // events may use traccar id
      }
    });
  }

  Future<void> _loadAlerts() async {
    final a = await ApiService.getAlerts();
    if (!mounted) return;
    setState(() {
      _alerts = a;
      _loadingAlerts = false;
    });
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoaded = true;
      _loadingEvents = true;
    });
    final e = await ApiService.getEvents();
    if (!mounted) return;
    setState(() {
      _events = e;
      _loadingEvents = false;
    });
  }

  static const _typeMeta = {
    'overspeed': {'name': 'Over Speed Alert', 'icon': Icons.speed, 'color': AppColors.red, 'bg': AppColors.redBg},
    'move_duration': {'name': 'Movement Alert', 'icon': Icons.trending_flat, 'color': AppColors.blue, 'bg': AppColors.blueBg},
    'ignition_duration': {'name': 'Engine On/Off Alert', 'icon': Icons.power_settings_new, 'color': AppColors.green, 'bg': AppColors.greenBg},
    'powercut': {'name': 'GPS Power Cut Alert', 'icon': Icons.flash_on, 'color': AppColors.orange, 'bg': AppColors.orangeBg},
    'lowbattery': {'name': 'Low Battery Alert', 'icon': Icons.battery_alert, 'color': AppColors.violet, 'bg': AppColors.violetBg},
  };

  Map _meta(String t) => _typeMeta[t] ?? {'name': 'Alert', 'icon': Icons.notifications, 'color': AppColors.teal, 'bg': AppColors.bg};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.teal, AppColors.teal2]),
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)), padding: const EdgeInsets.all(3), child: Image.asset('assets/logo-icon.png', errorBuilder: (_, __, ___) => const Icon(Icons.location_on, color: AppColors.teal, size: 20))),
                const SizedBox(width: 9),
                const Text('Bharat GPS Tracker', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              const Text('Alerts', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              TabBar(
                controller: _tab,
                indicatorColor: AppColors.amber,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [Tab(text: 'My Alerts'), Tab(text: 'History')],
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              _alertsTab(),
              _historyTab(),
            ]),
          ),
        ]),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) => _tab.index == 0
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.teal,
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _alertsTab() {
    if (_loadingAlerts) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.notifications_none, size: 50, color: AppColors.muted),
          SizedBox(height: 12),
          Text('No alerts yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text('Tap “Create” to add your first alert.', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
      itemCount: _alerts.length,
      itemBuilder: (_, i) {
        final a = _alerts[i];
        final t = (a['type'] ?? 'other').toString();
        final m = _meta(t);
        String cond = m['name'].toString();
        if (t == 'overspeed') cond = 'Speed > ${a['overspeed'] ?? '—'} km/h';
        else if (t == 'move_duration') cond = 'Alerts when vehicle moves';
        else if (t == 'ignition_duration') cond = 'Engine ON / OFF events';
        final devs = (a['devices'] as List?) ?? [];
        String vtxt = devs.isEmpty
            ? 'No vehicles'
            : (devs.length <= 2
                ? devs.map((id) => _names['$id'] ?? '#$id').join(', ')
                : '${devs.take(2).map((id) => _names['$id'] ?? '#$id').join(', ')} +${devs.length - 2} more');
        return Container(
          margin: const EdgeInsets.only(bottom: 11),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Color(0x0D0E5C5C), blurRadius: 10)]),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(12)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['name'] ?? m['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$cond · $vtxt', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
            ])),
            Switch(
              value: (a['active'] ?? 1) == 1,
              activeColor: AppColors.green,
              onChanged: (v) async {
                setState(() => a['active'] = v ? 1 : 0);
                final ok = await ApiService.toggleAlert(a['id']);
                if (!ok && mounted) setState(() => a['active'] = v ? 0 : 1);
              },
            ),
            GestureDetector(
              onTap: () => _confirmDelete(a),
              child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: 19, color: AppColors.muted)),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete alert?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await ApiService.deleteAlert(a['id']);
    if (done && mounted) setState(() => _alerts.remove(a));
  }

  Widget _historyTab() {
    if (_loadingEvents) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_events.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.history, size: 50, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No events yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text('Triggered alerts from the last 7 days appear here. An alert must actually fire (a vehicle does the thing) to create an event.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ]),
      );
    }
    String lastDay = '';
    final items = <Widget>[];
    for (final e in _events) {
      final day = _dayLabel(e['time']);
      if (day != lastDay) {
        items.add(Padding(padding: const EdgeInsets.fromLTRB(2, 10, 2, 9), child: Text(day, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4))));
        lastDay = day;
      }
      final t = _guessType((e['message'] ?? '').toString());
      final m = _meta(t);
      final vname = _names['${e['device_id']}'] ?? 'Device ${e['device_id']}';
      items.add(Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x0D0E5C5C), blurRadius: 10)]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: m['bg'] as Color, borderRadius: BorderRadius.circular(10)), child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 19)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e['message'] ?? m['name'], style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text('$vname${e['speed'] != null ? ' · ${(e['speed'] as num).round()} km/h' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
            const SizedBox(height: 3),
            Row(children: [
              const Icon(Icons.schedule, size: 11, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(_fullStamp(e['time']), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ])),
          Text(_timeLabel(e['time']), style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: items);
  }

  String _guessType(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('speed')) return 'overspeed';
    if (m.contains('mov')) return 'move_duration';
    if (m.contains('ignition') || m.contains('engine')) return 'ignition_duration';
    if (m.contains('power') || m.contains('charge')) return 'powercut';
    if (m.contains('batter')) return 'lowbattery';
    return 'other';
  }

  DateTime? _parse(dynamic t) => t == null ? null : DateTime.tryParse(t.toString().replaceFirst(' ', 'T'));
  String _dayLabel(dynamic t) {
    final d = _parse(t);
    if (d == null) return 'Earlier';
    final now = DateTime.now();
    final y = now.subtract(const Duration(days: 1));
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _timeLabel(dynamic t) {
    final d = _parse(t);
    return d != null ? DateFormat('hh:mm a').format(d) : '';
  }

  String _fullStamp(dynamic t) {
    final d = _parse(t);
    return d != null ? DateFormat('dd MMM yyyy, hh:mm a').format(d) : (t?.toString() ?? '—');
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateAlertSheet(devices: _devices, onCreated: () {
        setState(() => _loadingAlerts = true);
        _loadAlerts();
      }),
    );
  }
}

class _CreateAlertSheet extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final VoidCallback onCreated;
  const _CreateAlertSheet({required this.devices, required this.onCreated});
  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  String _type = 'overspeed';
  final _thr = TextEditingController(text: '60');
  final Set<String> _selected = {};
  bool _creating = false;

  static const _types = [
    {'t': 'overspeed', 'name': 'Over Speed', 'sub': 'Speed limit', 'icon': Icons.speed, 'color': AppColors.red, 'bg': AppColors.redBg},
    {'t': 'move_duration', 'name': 'Movement', 'sub': 'Moves when parked', 'icon': Icons.trending_flat, 'color': AppColors.blue, 'bg': AppColors.blueBg},
    {'t': 'ignition_duration', 'name': 'Engine On/Off', 'sub': 'Ignition', 'icon': Icons.power_settings_new, 'color': AppColors.green, 'bg': AppColors.greenBg},
    {'t': 'powercut', 'name': 'Power Cut', 'sub': 'GPS unplugged', 'icon': Icons.flash_on, 'color': AppColors.orange, 'bg': AppColors.orangeBg},
    {'t': 'lowbattery', 'name': 'Low Battery', 'sub': 'Below threshold', 'icon': Icons.battery_alert, 'color': AppColors.violet, 'bg': AppColors.violetBg},
  ];

  String get _thrLabel {
    switch (_type) {
      case 'overspeed':
        return 'Speed Limit';
      case 'move_duration':
        return 'Trigger after (minutes)';
      case 'ignition_duration':
        return 'Trigger after (minutes)';
      case 'lowbattery':
        return 'Battery below';
      default:
        return '';
    }
  }

  String get _thrUnit => _type == 'overspeed' ? 'km/h' : (_type == 'lowbattery' ? '%' : 'min');
  bool get _hasThreshold => _type != 'powercut';

  Future<void> _create() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one vehicle')));
      return;
    }
    setState(() => _creating = true);
    final meta = _types.firstWhere((e) => e['t'] == _type);
    final thr = int.tryParse(_thr.text) ?? 0;
    final ok = await ApiService.createAlert(
      type: _type,
      name: '${meta['name']} Alert',
      devices: _selected.map((e) => int.parse(e)).toList(),
      overspeed: _type == 'overspeed' ? thr : null,
      moveDuration: _type == 'move_duration' ? thr : null,
      ignitionDuration: _type == 'ignition_duration' ? thr : null,
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (ok) {
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert created')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text((_type == 'powercut' || _type == 'lowbattery')
            ? 'This alert may not be supported by your device/server'
            : 'Could not create alert'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
        Row(children: [
          const Expanded(child: Text('Create Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: AppColors.ink2))),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ALERT TYPE', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: _types.map((ty) {
                  final sel = _type == ty['t'];
                  return GestureDetector(
                    onTap: () => setState(() => _type = ty['t'] as String),
                    child: Container(
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFF1F8F7) : Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: sel ? AppColors.teal : AppColors.line, width: 1.6),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: ty['bg'] as Color, borderRadius: BorderRadius.circular(11)), child: Icon(ty['icon'] as IconData, color: ty['color'] as Color, size: 20)),
                        const SizedBox(height: 6),
                        Text(ty['name'] as String, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        Text(ty['sub'] as String, style: const TextStyle(fontSize: 10, color: AppColors.ink2)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              if (_hasThreshold) ...[
                const SizedBox(height: 16),
                Text(_thrLabel.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _thr,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.teal),
                        decoration: const InputDecoration(border: InputBorder.none),
                      ),
                    ),
                    Text(_thrUnit, style: const TextStyle(color: AppColors.ink2, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              const Text('APPLY TO', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  CheckboxListTile(
                    dense: true,
                    activeColor: AppColors.teal,
                    title: const Text('All vehicles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    value: _selected.length == widget.devices.length && widget.devices.isNotEmpty,
                    onChanged: (v) => setState(() {
                      _selected.clear();
                      if (v == true) _selected.addAll(widget.devices.map((u) => '${u['id']}'));
                    }),
                  ),
                  ...widget.devices.map((u) => CheckboxListTile(
                        dense: true,
                        activeColor: AppColors.teal,
                        title: Text(u['name'] ?? 'Device ${u['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: _selected.contains('${u['id']}'),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add('${u['id']}');
                          } else {
                            _selected.remove('${u['id']}');
                          }
                        }),
                      )),
                ]),
              ),
              if (_type == 'powercut' || _type == 'lowbattery')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text('Power Cut & Low Battery rely on your device reporting these alarms.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _creating ? null : _create,
            icon: _creating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add),
            label: const Text('Create Alert', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ]),
    );
  }
}
