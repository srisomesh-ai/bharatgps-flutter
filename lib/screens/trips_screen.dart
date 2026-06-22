import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav.dart';
import 'history_map_screen.dart';
import '../widgets/loaders.dart';

class TripsScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const TripsScreen({super.key, required this.device});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  int _days = 7;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final t = _customRange != null
        ? await ApiService.getTrips(
            deviceId: '${widget.device['id']}',
            from: DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day, 0, 0, 0),
            to: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day, 23, 59, 59),
          )
        : await ApiService.getTrips(deviceId: '${widget.device['id']}', days: _days);
    if (!mounted) return;
    setState(() {
      _trips = t;
      _loading = false;
    });
  }

  Future<void> _showHistoryDebug() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.teal)));
    final h = await ApiService.getHistory(deviceId: '${widget.device['id']}', days: _customRange == null ? _days : 7);
    final pts = (h['points'] as List?) ?? [];
    if (!mounted) return;
    Navigator.pop(context);
    final moving = pts.where((p) => (p['spd'] ?? 0) >= 3).length;
    final sample = pts.isNotEmpty ? pts.first.toString() : 'none';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('History check', style: TextStyle(fontSize: 15)),
        content: SingleChildScrollView(
          child: Text('Period: ${_customRange == null ? '$_days day(s)' : 'custom'}\n'
              'Total GPS points: ${pts.length}\n'
              'Moving points (>=3 km/h): $moving\n'
              'Distance: ${h['distance_km']} km\n\n'
              'First point:\n$sample\n\n'
              '${pts.isEmpty ? 'Server returned NO history — device has no recorded movement for this period.' : moving == 0 ? 'Points exist but none show movement >=3 km/h, so no trips formed.' : 'Movement exists — trips should appear.'}',
              style: const TextStyle(fontSize: 12)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _fmtTime(String iso) {
    final d = DateTime.tryParse(iso.replaceFirst(' ', 'T'));
    if (d == null) return iso;
    return DateFormat('h:mm a').format(d);
  }

  String _fmtDay(String iso) {
    final d = DateTime.tryParse(iso.replaceFirst(' ', 'T'));
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(d);
  }

  String _dur(int mins) {
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h ${mins % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final s = stateOf(widget.device['online'], widget.device['speed']);
    final movingNow = s == 'rn';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(children: [
        // header
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.teal2])),
          padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 16, 18),
          child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trips', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(widget.device['name'] ?? 'Vehicle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        // period selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _chip('Today', 1),
              const SizedBox(width: 8),
              _chip('7 Days', 7),
              const SizedBox(width: 8),
              _chip('14 Days', 14),
              const SizedBox(width: 8),
              _chip('30 Days', 30),
              const SizedBox(width: 8),
              _customChip(),
            ]),
          ),
        ),
        Expanded(
          child: _loading
              ? const RouteLoader()
              : _trips.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.route_outlined, size: 50, color: AppColors.muted),
                        const SizedBox(height: 12),
                        const Text('No trips found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 50), child: Text('Trips are detected automatically when the vehicle moves. None recorded for this period.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted))),
                        const SizedBox(height: 14),
                        TextButton.icon(onPressed: _showHistoryDebug, icon: const Icon(Icons.info_outline, size: 15), label: const Text('Check history data'), style: TextButton.styleFrom(foregroundColor: AppColors.teal)),
                      ]),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        if (movingNow) _liveBanner(),
                        // summary
                        _summary(),
                        const SizedBox(height: 8),
                        const Padding(padding: EdgeInsets.only(left: 2, bottom: 8, top: 6), child: Text('TRIP HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.5))),
                        ..._trips.asMap().entries.map((e) => _tripCard(e.value, e.key == 0 && movingNow)),
                      ],
                    ),
        ),
      ]),
      bottomNavigationBar: const BottomNav(current: 1),
    );
  }

  Widget _liveBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF2FBF5), Colors.white]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDEBD7), width: 1.5),
      ),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.navigation, color: AppColors.green)),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('On a trip now', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          Text('Engine running — trip in progress', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(20)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _summary() {
    final totalKm = _trips.fold<double>(0, (s, t) => s + (t['distance'] as num).toDouble());
    final totalMin = _trips.fold<int>(0, (s, t) => s + (t['duration_min'] as int));
    return Row(children: [
      _sumCard('${totalKm.toStringAsFixed(1)}', 'km', 'Distance', AppColors.blue, AppColors.blueBg),
      const SizedBox(width: 10),
      _sumCard('${_trips.length}', '', 'Trips', AppColors.teal, const Color(0xFFE3F0EF)),
      const SizedBox(width: 10),
      _sumCard(_dur(totalMin), '', 'Driving', AppColors.violet, AppColors.violetBg),
    ]);
  }

  Widget _sumCard(String v, String unit, String label, Color c, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 8)]),
        child: Column(children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c)),
            if (unit.isNotEmpty) TextSpan(text: ' $unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
          ])),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _tripCard(Map<String, dynamic> t, bool isLive) {
    return GestureDetector(
      onTap: () {
        // open the route playback for this trip's window
        final start = DateTime.tryParse('${t['start']}'.replaceFirst(' ', 'T'));
        final end = DateTime.tryParse('${t['end']}'.replaceFirst(' ', 'T'));
        if (start != null && end != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryMapScreen(device: widget.device, from: start, to: end)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0A0E5C5C), blurRadius: 8)]),
        child: Column(children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: isLive ? AppColors.greenBg : AppColors.blueBg, borderRadius: BorderRadius.circular(10)), child: Icon(isLive ? Icons.navigation : Icons.route, size: 18, color: isLive ? AppColors.green : AppColors.blue)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(_fmtDay('${t['start']}'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (isLive) ...[
                  const SizedBox(width: 7),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(10)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800))),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${_fmtTime('${t['start']}')} → ${isLive ? 'now' : _fmtTime('${t['end']}')}', style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${t['distance']} km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.teal)),
              Text(_dur(t['duration_min']), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _miniStat(Icons.speed, '${t['max_speed']} km/h', 'Max'),
              Container(width: 1, height: 22, color: AppColors.line),
              _miniStat(Icons.straighten, '${t['distance']} km', 'Distance'),
              Container(width: 1, height: 22, color: AppColors.line),
              _miniStat(Icons.timer_outlined, _dur(t['duration_min']), 'Time'),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniStat(IconData ic, String v, String l) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Icon(ic, size: 13, color: AppColors.teal),
        const SizedBox(width: 4),
        Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      Text(l, style: const TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _chip(String label, int days) {
    final sel = _customRange == null && _days == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          _days = days;
          _customRange = null;
        });
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.teal : AppColors.line, width: 1.4),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.ink2, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ),
    );
  }

  Widget _customChip() {
    final sel = _customRange != null;
    final label = sel
        ? '${_customRange!.start.day}/${_customRange!.start.month} - ${_customRange!.end.day}/${_customRange!.end.month}'
        : 'Custom';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 1),
          lastDate: now,
          initialDateRange: _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now),
        );
        if (picked != null) {
          setState(() => _customRange = picked);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.teal : AppColors.line, width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 13, color: sel ? Colors.white : AppColors.ink2),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.ink2, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
      ),
    );
  }
}
