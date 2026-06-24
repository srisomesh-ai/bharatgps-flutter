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
    {'name': 'Basic GPS', 'price': 3499, 'desc': 'Real-time tracking for cars, bikes & fleet', 'icon': Icons.gps_fixed},
    {'name': 'Engine Cut Off GPS', 'price': 4499, 'desc': 'Remotely immobilise the engine + live tracking', 'icon': Icons.power_settings_new},
    {'name': 'Magnet GPS', 'price': 5999, 'desc': 'Wireless magnetic tracker, no wiring needed', 'icon': Icons.attractions},
    {'name': 'Micro GPS', 'price': 3499, 'desc': 'Compact hidden tracker for discreet use', 'icon': Icons.memory},
    {'name': 'VLTD (RTO) GPS', 'price': 9499, 'desc': 'AIS-140 approved, RTO-compliant device', 'icon': Icons.verified},
  ];

  // services
  static const _services = [
    {'name': 'Change to Other Vehicle', 'price': 500, 'desc': 'Shift your GPS to a different vehicle', 'icon': Icons.swap_horiz},
    {'name': 'Remove (Vehicle Sold)', 'price': 500, 'desc': 'Deactivate & remove GPS from a sold vehicle', 'icon': Icons.remove_circle_outline},
    {'name': 'Re-Activation', 'price': 1500, 'desc': 'Reactivate a previously disabled device', 'icon': Icons.refresh},
    {'name': 'Troubleshoot', 'price': 350, 'desc': 'On-site diagnosis & fix for device issues', 'icon': Icons.build},
  ];

  // renewal plans
  static const _plans = [
    {'name': '3 Months', 'price': 350, 'free': ''},
    {'name': '6 Months', 'price': 700, 'free': ''},
    {'name': '1 Year', 'price': 1200, 'free': ''},
    {'name': '2 Years', 'price': 2400, 'free': ''},
    {'name': '4 Years', 'price': 4800, 'free': '1 Year Extra'},
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
      'https://api.whatsapp.com/send?phone=91$_phone&text=$encoded',
    ];
    for (final t in targets) {
      if (await _tryLaunch(t)) return;
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

  // Launch a URL directly WITHOUT canLaunchUrl gating. canLaunchUrl can falsely
  // return false for upi:// and whatsapp:// even when an app exists, so we just
  // try launchUrl and report success/failure from it.
  Future<bool> _tryLaunch(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
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
              onPay: () => _buyPay(d['name'] as String, d['price'] as int),
              onIconTap: () => _buyPayNoGst(d['name'] as String, d['price'] as int),
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
              actionLabel: 'Request',
              onPay: () => _buyPay(s['name'] as String, s['price'] as int),
              onIconTap: () => _buyPayNoGst(s['name'] as String, s['price'] as int),
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

  static const _upiId = 'sribharatgpstrackerprivatelimited.ibz@icici';
  // hidden no-GST UPI IDs (only used via the tap-the-icon shortcut)
  static const _upiNoGstBuy = '8985849521@uboi';
  static const _upiNoGstRenew = '9849849824@ybl';
  static const _payeeName = 'Bharat GPS Tracker';
  static const _renewWhatsApp = '9381874178';

  void _renewNow(Map plan, {bool noGst = false}) {
    Haptics.medium();
    final base = plan['price'] as int;
    final gst = noGst ? 0 : (base * 0.18).round();
    final total = base + gst;
    final planName = plan['name'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Text('Renew — $planName', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          // price breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _priceRow('Plan ($planName)', '₹${_fmt(base)}'),
              if (!noGst) ...[
                const SizedBox(height: 7),
                _priceRow('GST (18%)', '₹${_fmt(gst)}'),
              ],
              const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1)),
              _priceRow('Total Payable', '₹${_fmt(total)}', bold: true),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _payUpi(planName, total, upiOverride: noGst ? _upiNoGstRenew : null); },
              icon: const Icon(Icons.account_balance_wallet, size: 20),
              label: Text('Pay ₹${_fmt(total)} via UPI'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Opens PhonePe / Google Pay / Paytm with the amount pre-filled.', style: TextStyle(fontSize: 11.5, color: AppColors.ink2), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: bold ? AppColors.ink : AppColors.ink2)),
          Text(value, style: TextStyle(fontSize: bold ? 17 : 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.teal : AppColors.ink)),
        ],
      );

  Future<void> _payUpi(String planName, int amount, {String? upiOverride}) async {
    Haptics.medium();
    final note = 'GPS Renewal - $planName';
    final pa = upiOverride ?? _upiId;
    final upiUrl = 'upi://pay?pa=$pa&pn=${Uri.encodeComponent(_payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}';
    final opened = await _tryLaunch(upiUrl);
    if (!opened) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app found. Please install PhonePe, GPay or Paytm.')));
      return;
    }
    // after returning from the UPI app, prompt to share the screenshot
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) _screenshotPrompt(planName, amount);
  }

  void _screenshotPrompt(String planName, int amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: AppColors.teal)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Share Payment Screenshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          const Text(
            '1. Take a screenshot of your payment confirmation.\n2. Tap below to open WhatsApp and send it to us.\n3. We\'ll renew your GPS once verified.',
            style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _sendScreenshotWhatsApp(planName, amount); },
              icon: const Icon(Icons.chat, size: 20),
              label: const Text('Send Screenshot on WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal2, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _sendScreenshotWhatsApp(String planName, int amount) async {
    final msg = 'GPS Renewal Payment ✅\n\n'
        'Plan: $planName\n'
        'Amount Paid: ₹${_fmt(amount)} (incl. GST)\n'
        'Name: $_userName\n'
        'Account: $_userEmail\n\n'
        'Payment screenshot attached. Please renew my GPS.';
    final encoded = Uri.encodeComponent(msg);
    final targets = [
      'whatsapp://send?phone=91$_renewWhatsApp&text=$encoded',
      'https://wa.me/91$_renewWhatsApp?text=$encoded',
      'https://api.whatsapp.com/send?phone=91$_renewWhatsApp&text=$encoded',
    ];
    for (final t in targets) {
      if (await _tryLaunch(t)) return;
    }
    await Clipboard.setData(ClipboardData(text: msg));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not found — details copied')));
  }

  // ===== BUY GPS — pay with coupon discount =====
  // flat-amount coupon codes
  static const _coupons = {'GPS100': 100, 'SRI200': 200, 'BGT300': 300};

  // hidden no-GST shortcut (triggered by tapping the device icon)
  void _buyPayNoGst(String deviceName, int basePrice) {
    _buyPay(deviceName, basePrice, noGst: true, upiOverride: _upiNoGstBuy);
  }

  void _buyPay(String deviceName, int basePrice, {bool noGst = false, String? upiOverride}) {
    Haptics.medium();
    final couponCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    int discount = 0;
    String? appliedCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        final afterDiscount = (basePrice - discount).clamp(0, basePrice);
        final gst = noGst ? 0 : (afterDiscount * 0.18).round();
        final total = afterDiscount + gst;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(ctx).padding.bottom),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
                Text('Pay — $deviceName', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),

                // coupon
                const Text('COUPON CODE (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
                const SizedBox(height: 7),
                Row(children: [
                  Expanded(child: TextField(
                    controller: couponCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  )),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final code = couponCtrl.text.trim().toUpperCase();
                      if (_coupons.containsKey(code)) {
                        setSheet(() { discount = _coupons[code]!; appliedCode = code; });
                        Haptics.medium();
                      } else {
                        setSheet(() { discount = 0; appliedCode = null; });
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid coupon code')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
                if (appliedCode != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('✓ $appliedCode applied — ₹$discount off', style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w700))),
                const SizedBox(height: 14),

                // breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _priceRow('$deviceName', '₹${_fmt(basePrice)}'),
                    if (discount > 0) ...[
                      const SizedBox(height: 7),
                      _priceRow('Discount ($appliedCode)', '−₹${_fmt(discount)}'),
                      const SizedBox(height: 7),
                      _priceRow('After discount', '₹${_fmt(afterDiscount)}'),
                    ],
                    const SizedBox(height: 7),
                    if (!noGst) ...[
                      _priceRow('GST (18%)', '₹${_fmt(gst)}'),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 9), child: Divider(height: 1)),
                    ] else
                      const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Divider(height: 1)),
                    _priceRow('Total Payable', '₹${_fmt(total)}', bold: true),
                  ]),
                ),
                const SizedBox(height: 14),

                // remarks
                const Text('REMARKS (e.g. vehicle number / purpose)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink2, letterSpacing: 0.4)),
                const SizedBox(height: 7),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. AP39 WQ 3381 — already purchased',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _payUpiBuy(deviceName, total, remarksCtrl.text.trim(), appliedCode, upiOverride: upiOverride);
                    },
                    icon: const Icon(Icons.account_balance_wallet, size: 20),
                    label: Text('Pay ₹${_fmt(total)} via UPI'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _payUpiBuy(String deviceName, int amount, String remarks, String? coupon, {String? upiOverride}) async {
    Haptics.medium();
    final note = remarks.isNotEmpty ? 'GPS - $deviceName - $remarks' : 'GPS Purchase - $deviceName';
    final pa = upiOverride ?? _upiId;
    final upiUrl = 'upi://pay?pa=$pa&pn=${Uri.encodeComponent(_payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}';
    final opened = await _tryLaunch(upiUrl);
    if (!opened) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No UPI app found. Please install PhonePe, GPay or Paytm.')));
      return;
    }
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) _buyScreenshotPrompt(deviceName, amount, remarks, coupon);
  }

  void _buyScreenshotPrompt(String deviceName, int amount, String remarks, String? coupon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: AppColors.teal)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Share Payment Screenshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          const Text('1. Take a screenshot of your payment.\n2. Tap below to send it to us on WhatsApp.\n3. We\'ll process your order once verified.', style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(context); _buySendScreenshot(deviceName, amount, remarks, coupon); },
              icon: const Icon(Icons.chat, size: 20),
              label: const Text('Send Screenshot on WhatsApp'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal2, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _buySendScreenshot(String deviceName, int amount, String remarks, String? coupon) async {
    final msg = 'GPS Purchase Payment ✅\n\n'
        'Device: $deviceName\n'
        'Amount Paid: ₹${_fmt(amount)} (incl. GST)\n'
        '${coupon != null ? 'Coupon: $coupon\n' : ''}'
        '${remarks.isNotEmpty ? 'Remarks: $remarks\n' : ''}'
        'Name: $_userName\n'
        'Account: $_userEmail\n\n'
        'Payment screenshot attached. Please process my order.';
    final encoded = Uri.encodeComponent(msg);
    // GPS sales screenshots go to _phone (9849849824)
    final targets = [
      'whatsapp://send?phone=91$_phone&text=$encoded',
      'https://wa.me/91$_phone?text=$encoded',
      'https://api.whatsapp.com/send?phone=91$_phone&text=$encoded',
    ];
    for (final t in targets) {
      if (await _tryLaunch(t)) return;
    }
    await Clipboard.setData(ClipboardData(text: msg));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp not found — details copied')));
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

  Widget _productCard({required IconData icon, required String name, required String desc, required int price, required String priceNote, required String actionLabel, required VoidCallback onAction, VoidCallback? onPay, VoidCallback? onIconTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // hidden no-GST shortcut: tapping the icon opens the no-GST payment
          GestureDetector(
            onTap: onIconTap,
            child: Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: AppColors.teal, size: 25)),
          ),
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
          if (onPay != null) ...[
            OutlinedButton(
              onPressed: onPay,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.teal, side: const BorderSide(color: AppColors.teal, width: 1.4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
              child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
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
            // hidden no-GST shortcut: tap the plan name
            GestureDetector(
              onTap: () => _renewNow(p, noGst: true),
              child: Text(p['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
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
