import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  String _selected = 'default';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await NotificationService.currentSound();
    if (mounted) setState(() => _selected = s.id);
  }

  Future<void> _pick(AlertSound s) async {
    setState(() => _selected = s.id);
    await NotificationService.setSound(s.id);
  }

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
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text('ALERT SOUND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.5)),
              ),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
                child: Column(
                  children: List.generate(kAlertSounds.length, (i) {
                    final s = kAlertSounds[i];
                    final sel = _selected == s.id;
                    return InkWell(
                      onTap: () => _pick(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(border: i == kAlertSounds.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.line))),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: sel ? AppColors.teal : AppColors.bg, borderRadius: BorderRadius.circular(11)),
                            child: Icon(Icons.music_note, size: 19, color: sel ? Colors.white : AppColors.ink2),
                          ),
                          const SizedBox(width: 13),
                          Expanded(child: Text(s.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                          // preview button
                          GestureDetector(
                            onTap: () async {
                              await NotificationService.preview(s);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Playing "${s.label}" — check your notification shade'), duration: const Duration(seconds: 2)),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                                Icon(Icons.play_arrow, size: 15, color: AppColors.teal),
                                SizedBox(width: 3),
                                Text('Play', style: TextStyle(fontSize: 11.5, color: AppColors.teal, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // selected check
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: sel ? AppColors.teal : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: sel ? AppColors.teal : const Color(0xFFC2CFCF), width: 2),
                            ),
                            child: sel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                        ]),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(color: const Color(0xFFF1F8F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD6EBE8))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  Icon(Icons.info_outline, size: 17, color: AppColors.teal),
                  SizedBox(width: 9),
                  Expanded(child: Text('Tap “Play” to preview a sound. Your selected tone plays for all vehicle alerts. On Android, the sound applies to new notifications.', style: TextStyle(fontSize: 12, color: AppColors.ink2, height: 1.4))),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
