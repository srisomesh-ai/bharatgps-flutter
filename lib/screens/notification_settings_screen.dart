import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
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
            const Text('Notification Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              // enable toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_active, color: AppColors.green)),
                  const SizedBox(width: 13),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Push Notifications', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    Text('Get alerts for speed, offline, power cut & more', style: TextStyle(fontSize: 11.5, color: AppColors.ink2)),
                  ])),
                  Switch(value: _enabled, activeColor: AppColors.green, onChanged: (v) => setState(() => _enabled = v)),
                ]),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFF1F8F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD6EBE8))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Icon(Icons.info_outline, size: 17, color: AppColors.teal),
                  SizedBox(width: 9),
                  Expanded(child: Text('Alert sounds are chosen when you create each alert (Alerts tab → + → choose English / Hindi / Telugu / Other Tones). If no sound is chosen, the phone\'s default notification sound is used.', style: TextStyle(fontSize: 12, color: AppColors.ink2, height: 1.4))),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
