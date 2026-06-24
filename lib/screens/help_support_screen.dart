import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  // contact details (from bharatgps.store)
  static const _phone = '919849849824';
  static const _email = 'support@bharatgps.com';

  int? _openFaq;

  Future<void> _launch(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open app')));
    }
  }

  void _call() => _launch(Uri.parse('tel:+$_phone'));
  void _whatsapp([String msg = 'Hello, I need help with my Bharat GPS Tracker.']) =>
      _launch(Uri.parse('https://wa.me/$_phone?text=${Uri.encodeComponent(msg)}'));
  void _mail(String subject) => _launch(Uri.parse('mailto:$_email?subject=${Uri.encodeComponent(subject)}'));

  static const _faqs = [
    ['❓', 'How does the GPS tracker work?',
      'The device uses satellite (GPS) signals to capture your vehicle\'s exact location, speed and movement, then sends it to our servers over the SIM network. You see it live on this app, anytime, anywhere.'],
    ['⚡', 'What is the Engine Cut-Off feature?',
      'If your device has the engine cut-off relay installed, you can remotely turn the engine OFF/ON from the app — useful in case of theft. The option appears in the vehicle details only for devices that support it.'],
    ['🔔', 'What alerts can I receive?',
      'Ignition ON/OFF, over-speeding, geofence entry/exit, device offline, power disconnection and anti-theft alarms. You can set custom alert sounds for each type in the Alerts section.'],
    ['▦', 'How do I set up a Geofence?',
      'Go to Alerts → Geofence, draw a circle or polygon around any area on the map, name it, and save. You\'ll get notified whenever your vehicle enters or exits that zone.'],
    ['🛡️', 'Is there an anti-theft alarm?',
      'Yes. You get an instant alert if the vehicle\'s ignition is turned on, or if it\'s moved by towing or pushing — even when the engine is off.'],
    ['🔋', 'Will it drain my vehicle battery?',
      'No. The device uses advanced sleep & wake technology for minimal power use, and draws power from both its internal battery and the vehicle — designed to be battery-friendly.'],
    ['📅', 'How do I renew my plan?',
      'Go to Profile → Store & Services → Renew tab. Choose your plan (3 months to 4 years), pay via UPI, and share the screenshot on WhatsApp. Your plan is renewed instantly.'],
  ];

  static const _features = [
    ['📍', 'Real-Time Live Tracking', 'Highly sensitive GPS chip sends your vehicle\'s accurate location live to the app.'],
    ['🛣️', 'Travel History & Playback', 'Replay the full day\'s driving history with route, speed and stops.'],
    ['⚡', 'Remote Engine ON/OFF', 'Get ignition alerts and remotely cut the engine for anti-theft control.'],
    ['▦', 'Geo-Fencing', 'Set safe zones and get alerts on entry or exit.'],
    ['🚨', 'Anti-Theft Alarm', 'Instant alert if the vehicle is towed, pushed or ignition turned on.'],
    ['🔋', 'Low Power Consumption', 'Smart sleep/wake tech keeps it vehicle-battery friendly.'],
    ['🔧', 'Hidden & Universal Fit', 'Compact — fits any vehicle: bike, car, scooty, EV, truck.'],
    ['🛡️', '1-Year Replacement Warranty', 'Comprehensive warranty for complete peace of mind.'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [
        // header
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 22),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.teal, AppColors.teal2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Column(children: [
              Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20)),
                const Spacer(),
              ]),
              const SizedBox(height: 6),
              const Text('Help & Support', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              const Text("We're here to help you 24/7", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              const SizedBox(height: 8),
            ]),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _sectionTitle('Get in Touch'),
            // contact grid
            Row(children: [
              Expanded(child: _contactCard('📞', 'Call Us', '98498 49824', const Color(0xFFe6f5ec), AppColors.green, _call)),
              const SizedBox(width: 10),
              Expanded(child: _contactCard('✉️', 'Email', 'support@bharatgps.com', const Color(0xFFe7f0fb), const Color(0xFF2980b9), () => _mail('Bharat GPS — Support Request'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _contactCard('📝', 'Raise Complaint', 'Report an issue', const Color(0xFFfdeee0), AppColors.amber, () => _whatsapp('Complaint: I want to report an issue with my Bharat GPS Tracker.'))),
              const SizedBox(width: 10),
              Expanded(child: _contactCard('💡', 'Suggestion', 'Share an idea', const Color(0xFFeee9fb), const Color(0xFF8e44ad), () => _mail('Bharat GPS — Suggestion'))),
            ]),
            const SizedBox(height: 11),
            // whatsapp banner
            GestureDetector(
              onTap: () => _whatsapp(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF25D366).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 4))]),
                child: Row(children: [
                  const Text('💬', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('24/7 WhatsApp Helpline', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Fastest support — chat with us now', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ])),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),

            _sectionTitle('Frequently Asked Questions'),
            ...List.generate(_faqs.length, (i) => _faqTile(i)),

            _sectionTitle('GPS Device Features'),
            ..._features.map((f) => _featureTile(f[0], f[1], f[2])),

            const SizedBox(height: 18),
            Center(child: Column(children: const [
              Text('Bharat GPS Tracker', style: TextStyle(color: AppColors.teal, fontSize: 13, fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text("India's Best Vehicle Tracking System", style: TextStyle(color: AppColors.ink2, fontSize: 11)),
              SizedBox(height: 3),
              Text('📞 +91 98498 49824 · ✉️ support@bharatgps.com', style: TextStyle(color: AppColors.ink2, fontSize: 10.5)),
            ])),
            const SizedBox(height: 26),
          ])),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink2, letterSpacing: 0.6)),
      );

  Widget _contactCard(String emoji, String label, String sub, Color bg, Color fg, VoidCallback onTap) => GestureDetector(
        onTap: () { Haptics.light(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
          child: Column(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
            const SizedBox(height: 9),
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.ink2)),
          ]),
        ),
      );

  Widget _faqTile(int i) {
    final f = _faqs[i];
    final open = _openFaq == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x0A0E5C5C), blurRadius: 8)]),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () { Haptics.light(); setState(() => _openFaq = open ? null : i); },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(children: [
              Text(f[0], style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(f[1], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink))),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 220), child: const Icon(Icons.keyboard_arrow_down, color: AppColors.ink2, size: 20)),
            ]),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 14),
            child: Align(alignment: Alignment.centerLeft, child: Text(f[2], style: const TextStyle(fontSize: 12, color: AppColors.ink2, height: 1.55))),
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _featureTile(String emoji, String title, String desc) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x0A0E5C5C), blurRadius: 8)]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.teal, AppColors.teal2]), borderRadius: BorderRadius.circular(11)), child: Center(child: Text(emoji, style: const TextStyle(fontSize: 19)))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.ink2, height: 1.45)),
          ])),
        ]),
      );
}
