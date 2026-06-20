import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

/// Offline-vehicle troubleshoot: scanner animation (3s) then AI-typed conclusion.
class TroubleshootSheet extends StatefulWidget {
  final Map<String, dynamic> device;
  const TroubleshootSheet({super.key, required this.device});
  @override
  State<TroubleshootSheet> createState() => _TroubleshootSheetState();
}

class _TroubleshootSheetState extends State<TroubleshootSheet> with SingleTickerProviderStateMixin {
  late AnimationController _ring;
  bool _scanning = true;
  int _pct = 0;
  String _step = 'Connecting to device';
  String _typed = '';
  String _conclusion = '';
  List<Map<String, String>> _cards = [];
  final _steps = ['Connecting to device', 'Checking engine status', 'Verifying power supply', 'Reading GPS signal', 'Analysing last events'];
  Timer? _pctTimer, _stepTimer, _typeTimer;
  int _stepIdx = 0;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _compute();
    _runScan();
  }

  @override
  void dispose() {
    _ring.dispose();
    _pctTimer?.cancel();
    _stepTimer?.cancel();
    _typeTimer?.cancel();
    super.dispose();
  }

  void _runScan() {
    final start = DateTime.now();
    _pctTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      final p = ((DateTime.now().difference(start).inMilliseconds) / 3000 * 100).clamp(0, 100).round();
      if (mounted) setState(() => _pct = p);
      if (p >= 100) t.cancel();
    });
    _stepTimer = Timer.periodic(const Duration(milliseconds: 600), (t) {
      _stepIdx++;
      if (_stepIdx >= _steps.length) {
        t.cancel();
        return;
      }
      if (mounted) setState(() => _step = _steps[_stepIdx]);
    });
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _scanning = false);
      _typeConclusion();
    });
  }

  void _typeConclusion() {
    int i = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (i >= _conclusion.length) {
        t.cancel();
        return;
      }
      i++;
      if (mounted) setState(() => _typed = _conclusion.substring(0, i));
    });
  }

  void _compute() {
    final t = (widget.device['ts'] ?? {}) as Map;
    final ign = tBool(t['ignition']);
    final charge = tBool(t['charge']);
    final blocked = tBool(t['blocked']);
    final valid = tBool(t['valid']);
    final motion = tBool(t['motion']);
    final batt = (t['battery'] != null && t['battery'].toString().isNotEmpty) ? double.tryParse(t['battery'].toString()) : null;
    final alarm = (t['alarm'] ?? '').toString().toLowerCase();

    final cards = <Map<String, String>>[];
    if (ign == true) cards.add({'cls': 'warn', 'ic': 'engine', 'title': 'Engine Status', 'sub': 'Engine was ON when it went offline', 'val': 'ON'});
    else if (ign == false) cards.add({'cls': 'ok', 'ic': 'engine', 'title': 'Engine Status', 'sub': 'Engine was OFF — device may be in sleep mode', 'val': 'OFF'});

    if (charge == false) cards.add({'cls': 'bad', 'ic': 'power', 'title': 'GPS Power Supply', 'sub': 'Main power appears DISCONNECTED', 'val': 'CUT'});
    else if (charge == true) cards.add({'cls': 'ok', 'ic': 'power', 'title': 'GPS Power Supply', 'sub': 'Power supply OK', 'val': 'OK'});

    if (blocked == true) cards.add({'cls': 'warn', 'ic': 'block', 'title': 'Engine Cut-off', 'sub': 'Engine cut-off relay is ACTIVE', 'val': 'ACTIVE'});

    if (batt != null) {
      if (batt <= 10) cards.add({'cls': 'bad', 'ic': 'batt', 'title': 'Device Battery', 'sub': 'Backup battery critically low', 'val': '${batt.round()}%'});
      else if (batt <= 30) cards.add({'cls': 'warn', 'ic': 'batt', 'title': 'Device Battery', 'sub': 'Backup battery low', 'val': '${batt.round()}%'});
      else cards.add({'cls': 'ok', 'ic': 'batt', 'title': 'Device Battery', 'sub': 'Battery healthy', 'val': '${batt.round()}%'});
    }

    if (valid == false) cards.add({'cls': 'warn', 'ic': 'gps', 'title': 'GPS Fix', 'sub': 'No valid GPS fix — poor sky view', 'val': 'LOST'});
    else if (valid == true) cards.add({'cls': 'ok', 'ic': 'gps', 'title': 'GPS Fix', 'sub': 'GPS fix was valid', 'val': 'OK'});

    cards.add({'cls': 'warn', 'ic': 'clock', 'title': 'Last Seen', 'sub': t['last_seen'] != null ? 'Offline for ${t['last_seen']}' : 'Recently', 'val': ''});

    if (alarm.isNotEmpty && alarm != '0' && alarm != 'none') {
      cards.add({'cls': 'bad', 'ic': 'alarm', 'title': 'Last Event', 'sub': alarm.toUpperCase(), 'val': ''});
    }

    String concl;
    if (alarm.contains('powercut') || alarm.contains('power cut') || alarm.contains('power_cut') || charge == false) {
      concl = 'The GPS device lost its main power supply. Check the 12V power wire, the in-line fuse, and the vehicle battery connection. The device ran on backup battery and then went offline.';
    } else if (alarm.contains('tamper')) {
      concl = 'Possible tampering detected. Inspect the device casing and wiring, and re-seal if needed.';
    } else if (alarm.contains('blind')) {
      concl = 'Device is in a GPS/GSM blind spot (covered parking, basement, or no-network area). It usually recovers automatically once the vehicle moves to open sky.';
    } else if (valid == false) {
      concl = 'Device has no GPS fix — likely parked under cover or with a blocked antenna. Move the vehicle to open sky; it should reconnect.';
    } else if (motion == true) {
      concl = 'Device went offline while moving — likely a GSM dead-zone or SIM issue. Check SIM balance and network coverage on that route.';
    } else if (ign == false) {
      concl = 'Engine was turned OFF and the device entered sleep mode. It will come back online automatically when the ignition is turned ON.';
    } else if (batt != null && batt <= 10) {
      concl = 'Device backup battery is critically low and main power may be weak. Check the power connection and charging.';
    } else {
      concl = 'Device went offline unexpectedly. Check: 1) SIM active with balance, 2) network coverage, 3) power wire and fuse, 4) device LED status.';
    }
    _cards = cards;
    _conclusion = concl;
  }

  IconData _icon(String k) {
    switch (k) {
      case 'engine':
        return Icons.power_settings_new;
      case 'power':
        return Icons.flash_on;
      case 'block':
        return Icons.block;
      case 'batt':
        return Icons.battery_alert;
      case 'gps':
        return Icons.gps_not_fixed;
      case 'alarm':
        return Icons.notifications_active;
      default:
        return Icons.schedule;
    }
  }

  Color _cardColor(String cls) => cls == 'ok' ? AppColors.green : (cls == 'warn' ? AppColors.orange : AppColors.red);
  Color _cardBg(String cls) => cls == 'ok' ? AppColors.greenBg : (cls == 'warn' ? AppColors.orangeBg : AppColors.redBg);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 18 + MediaQuery.of(context).padding.bottom),
      child: _scanning ? _scanView() : _resultView(),
    );
  }

  Widget _scanView() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: const Color(0xFFD8E0DE), borderRadius: BorderRadius.circular(3))),
      SizedBox(
        width: 128, height: 128,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _ring,
            builder: (_, __) => SizedBox(
              width: 128, height: 128,
              child: CircularProgressIndicator(value: _ring.value, strokeWidth: 6, backgroundColor: AppColors.line, valueColor: const AlwaysStoppedAnimation(AppColors.teal)),
            ),
          ),
          const Icon(Icons.local_shipping, size: 40, color: AppColors.teal),
          Positioned(bottom: 14, child: Text('$_pct%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.teal))),
        ]),
      ),
      const SizedBox(height: 22),
      const Text('Running Diagnosis', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('$_step…', style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
      const SizedBox(height: 24),
    ]);
  }

  Widget _resultView() {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFD8E0DE), borderRadius: BorderRadius.circular(3)))),
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.error_outline, color: AppColors.red, size: 23)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.device['name'] ?? 'Vehicle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Diagnosis complete', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
          ])),
          GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: AppColors.ink2))),
        ]),
        const SizedBox(height: 16),
        // Likely cause (AI typed)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF1F8F7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD6EBE8))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lightbulb_outline, size: 17, color: AppColors.teal),
              const SizedBox(width: 6),
              const Text('Likely Cause', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.auto_awesome, size: 11, color: Colors.white), SizedBox(width: 3), Text('AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))]),
              ),
            ]),
            const SizedBox(height: 8),
            Text(_typed, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.ink)),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Diagnostic Report', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink2)),
        const SizedBox(height: 10),
        ..._cards.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _cardBg(c['cls']!), borderRadius: BorderRadius.circular(10)), child: Icon(_icon(c['ic']!), color: _cardColor(c['cls']!), size: 18)),
                const SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['title']!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if ((c['sub'] ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(c['sub']!, style: const TextStyle(fontSize: 12, color: AppColors.ink2, height: 1.35))),
                ])),
                if ((c['val'] ?? '').isNotEmpty) Text(c['val']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _cardColor(c['cls']!))),
              ]),
            )),
      ]),
    );
  }
}
