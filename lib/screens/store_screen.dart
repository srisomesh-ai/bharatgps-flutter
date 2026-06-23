import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

/// Store & Services — Buy GPS devices, request services, renew plans.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _salesEmail = 'sales@bharatgps.com';
  static const _supportEmail = 'support@bharatgps.com';
  static const _phone = '9849849824';

  // device catalogue
  static const _devices = [
    {'name': 'Basic GPS', 'price': 3500, 'desc': 'Real-time tracking for cars, bikes & fleet', 'icon': Icons.gps_fixed},
    {'name': 'Engine Cut Off GPS', 'price': 4500, 'desc': 'Remotely immobilise the engine + live tracking', 'icon': Icons.power_settings_new},
    {'name': 'Magnet GPS', 'price': 5500, 'desc': 'Wireless magnetic tracker, no wiring needed', 'icon': Icons.attractions},
    {'name': 'Micro GPS', 'price': 4000, 'desc': 'Compact hidden tracker for discreet use', 'icon': Icons.memory},
    {'name': 'VLTD (RTO) GPS', 'price': 11000, 'desc': 'AIS-140 approved, RTO-compliant device', 'icon': Icons.verified},
  ];

  // services
  static const _services = [
    {'name': 'Change to Other Vehicle', 'price': 500, 'desc': 'Shift your GPS to a different vehicle', 'icon': Icons.swap_horiz},
    {'name': 'Remove (Vehicle Sold)', 'price': 500, 'desc': 'Deactivate & remove GPS from a sold vehicle', 'icon': Icons.remove_circle_outline},
    {'name': 'Re-Activation', 'price': 1500, 'desc': 'Reactivate a previously disabled device', 'icon': Icons.refresh},
  ];

  // renewal plans
  static const _plans = [
    {'name': '3 Months', 'price': 300, 'free': ''},
    {'name': '6 Months', 'price': 600, 'free': ''},
    {'name': '1 Year', 'price': 1200, 'free': ''},
    {'name': '2 Years', 'price': 2000, 'free': ''},
    {'name': '5 Years', 'price': 4000, 'free': '1 Year Free'},
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String get _userName => ApiService.userName ?? 'Customer';
  String get _userEmail => ApiService.userEmail ?? '';

  // ---- contact actions (Email / WhatsApp / Call) ----
  void _contactSheet({required String title, required String message, required String email}) {
    Haptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('How would you like to reach us?', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 16),
          _contactBtn(Icons.email_outlined, 'Send Email', AppColors.teal, () => _sendEmail(email, title, message)),
          const SizedBox(height: 10),
          _contactBtn(Icons.chat, 'Send WhatsApp', AppColors.teal2, () => _sendWhatsApp(message)),
          const SizedBox(height: 10),
          _contactBtn(Icons.call, 'Call Us', AppColors.amber, _call),
        ]),
      ),
    );
  }

  Widget _contactBtn(IconData ic, String label, Color color, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () { Navigator.pop(context); onTap(); },
          icon: Icon(ic, size: 20),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        ),
      );

  Future<void> _sendEmail(String to, String subject, String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    await _launch(uri, 'email app');
  }

  Future<void> _sendWhatsApp(String message) async {
    final encoded = Uri.encodeComponent(message);
    final targets = [
      'whatsapp://send?phone=91$_phone&text=$encoded',
      'https://wa.me/91$_phone?text=$encoded',
    ];
    for (final t in targets) {
      try {
        final uri = Uri.parse(t);
        if (await canLaunchUrl(uri)) {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
        }
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not found — message copied')));
  }

  Future<void> _call() async {
    await _launch(Uri.parse('tel:$_phone'), 'phone');
  }

  Future<void> _launch(Uri uri, String what) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'failed';
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $what')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        title: const Text('Store & Services', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'Buy GPS'), Tab(text: 'Services'), Tab(text: 'Renew')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buyTab(), _servicesTab(), _renewTab()],
      ),
    );
  }

  // ---- TAB 1: Buy GPS ----
  Widget _buyTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _banner(Icons.local_offer, 'Get a quotation for the best price', 'Ask for a quote — special discounts available. GST applicable.'),
        const SizedBox(height: 14),
        ..._devices.map((d) => _productCard(
              icon: d['icon'] as IconData,
              name: d['name'] as String,
              desc: d['desc'] as String,
              price: d['price'] as int,
              priceNote: '+ GST',
              actionLabel: 'Get Quotation',
              onAction: () => _contactSheet(
                title: 'Quotation — ${d['name']}',
                email: _salesEmail,
                message: "I'm interested in ${d['name']} (₹${_fmt(d['price'] as int)} + GST).\n\nName: $_userName\nAccount: $_userEmail\n\nPlease share the best quotation & discount.",
              ),
            )),
      ],
    );
  }

  // ---- TAB 2: Services ----
  Widget _servicesTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _banner(Icons.build_circle, 'GPS Services', 'Fixed prices shown below. GST applicable.'),
        const SizedBox(height: 14),
        ..._services.map((s) => _productCard(
              icon: s['icon'] as IconData,
              name: s['name'] as String,
              desc: s['desc'] as String,
              price: s['price'] as int,
              priceNote: '+ GST',
              actionLabel: 'Request Service',
              onAction: () => _contactSheet(
                title: 'Service — ${s['name']}',
                email: _supportEmail,
                message: "Service required: ${s['name']} (₹${_fmt(s['price'] as int)} + GST).\n\nName: $_userName\nAccount: $_userEmail\n\nPlease assist with this service request.",
              ),
            )),
      ],
    );
  }

  // ---- TAB 3: Renew ----
  Widget _renewTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _banner(Icons.autorenew, 'Renew Your GPS Plan', 'Keep your devices active. GST applicable.'),
        const SizedBox(height: 14),
        ..._plans.map((p) => _planCard(p)),
        const SizedBox(height: 8),
        // Refer & earn
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.teal, AppColors.teal2]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.9), shape: BoxShape.circle), child: const Icon(Icons.card_giftcard, color: Colors.white)),
            const SizedBox(width: 13),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Refer & Get Extra Months', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Invite friends to BharatGPS and earn free months on your plan.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3)),
            ])),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _referFriend,
            icon: const Icon(Icons.share, size: 18, color: AppColors.teal),
            label: const Text('Refer a Friend', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.teal, width: 1.4), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          ),
        ),
      ],
    );
  }

  Future<void> _referFriend() async {
    Haptics.medium();
    const msg = 'I use BharatGPS Tracker for my vehicle — accurate real-time GPS tracking! 🛰\n\n'
        'Get yours at http://bharatgps.store';
    await _sendWhatsApp(msg);
  }

  void _renewNow(Map plan) {
    Haptics.medium();
    // Razorpay coming later — for now route to sales to arrange renewal
    _contactSheet(
      title: 'Renew — ${plan['name']}',
      email: _salesEmail,
      message: "I'd like to renew my GPS plan: ${plan['name']} (₹${_fmt(plan['price'] as int)} + GST).\n\nName: $_userName\nAccount: $_userEmail\n\nPlease help me renew.",
    );
  }

  // ---- shared widgets ----
  Widget _banner(IconData ic, String title, String sub) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF1F8F7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD6EBE8))),
        child: Row(children: [
          Icon(ic, color: AppColors.teal, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.3)),
          ])),
        ]),
      );

  Widget _productCard({required IconData icon, required String name, required String desc, required int price, required String priceNote, required String actionLabel, required VoidCallback onAction}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.teal, size: 25)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.3)),
          ])),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('₹${_fmt(price)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.teal)),
          const SizedBox(width: 5),
          Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(priceNote, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600))),
          const Spacer(),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
      ]),
    );
  }

  Widget _planCard(Map p) {
    final hasFree = (p['free'] as String).isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hasFree ? Border.all(color: AppColors.amber, width: 2) : null,
        boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)],
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (hasFree) ...[
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(20)), child: Text(p['free'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('₹${_fmt(p['price'] as int)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.teal)),
            const SizedBox(width: 4),
            const Text('+ GST', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ]),
        const Spacer(),
        ElevatedButton(
          onPressed: () => _renewNow(p),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
          child: const Text('Renew Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    // Indian-style thousands grouping for small numbers is fine as plain
    if (s.length <= 3) return s;
    // simple comma grouping
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
