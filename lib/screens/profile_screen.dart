import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tour_keys.dart';
import 'main_shell.dart';
import '../services/api_service.dart';
import 'store_screen.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int total = 0, run = 0, idle = 0, off = 0;
  String _plan = 'Active Plan';
  String _valid = 'Tap to view details';
  Map<String, dynamic>? _userData; // full account data from server

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadPlan();
  }

  Future<void> _loadStats() async {
    final d = await ApiService.getDevices();
    if (!mounted) return;
    int r = 0, i = 0, o = 0;
    for (final u in d) {
      final s = stateOf(u['online'], u['speed']);
      if (s == 'rn') r++;
      else if (s == 'id') i++;
      else o++;
    }
    setState(() {
      total = d.length;
      run = r;
      idle = i;
      off = o;
    });
  }

  Future<void> _loadPlan() async {
    final u = await ApiService.getUserData();
    if (!mounted || u == null) return;
    setState(() {
      _userData = u;
      if (u['plan'] != null) _plan = u['plan'].toString();
      final days = u['days_left'];
      if (u['expiration_date'] != null) {
        final exp = u['expiration_date'].toString();
        _valid = days != null ? 'Valid till $exp · $days days left' : 'Valid till $exp';
      }
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You\'ll need to sign in again to access your fleet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) {
      await ApiService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _soon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon'), duration: const Duration(seconds: 2)));
  }

  // Shows the real account information pulled from the server.
  void _showAccountInfo() {
    Haptics.light();
    final u = _userData ?? {};
    final rows = <List<String>>[
      ['Name', ApiService.userName ?? '—'],
      ['Email', (u['email'] ?? ApiService.userEmail ?? '—').toString()],
      ['Plan', (u['plan'] ?? _plan).toString()],
      ['Expiry Date', (u['expiration_date'] ?? '—').toString()],
      ['Days Left', u['days_left'] != null ? '${u['days_left']} days' : '—'],
      ['Device Limit', u['devices_limit'] != null ? '${u['devices_limit']}' : '—'],
      ['Total Vehicles', '$total'],
      ['Server', ApiService.host ?? '—'],
    ];
    _showSheet('Account Information', Icons.person_outline, rows);
  }

  void _showAbout() {
    Haptics.light();
    final rows = <List<String>>[
      ['App', 'Bharat GPS Tracker'],
      ['Version', '1.0.0'],
      ['Server', ApiService.host ?? '—'],
      ['Account', ApiService.userEmail ?? ApiService.userName ?? '—'],
      ['Powered by', 'BharatGPS'],
    ];
    _showSheet('About Bharat GPS Tracker', Icons.info_outline, rows);
  }

  void _showSheet(String title, IconData icon, List<List<String>> rows) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFFE2E9E8), borderRadius: BorderRadius.circular(3)))),
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: AppColors.teal, size: 21)),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(r[0], style: const TextStyle(fontSize: 13, color: AppColors.ink2, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(r[1], style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                ]),
              )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = ApiService.userName ?? 'BharatGPS User';
    final email = ApiService.userEmail ?? '';
    return Scaffold(
      body: Column(children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.teal, AppColors.teal2])),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 18, 16, 18),
            child: Row(children: [
              const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(onPressed: () => MainShell.of(context)?.goTo(3), icon: const Icon(Icons.notifications_none, color: Colors.white), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 14),
              IconButton(onPressed: () => _soon('Settings'), icon: const Icon(Icons.settings_outlined, color: Colors.white), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Column(children: [
                    // profile card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x140E5C5C), blurRadius: 16)]),
                      child: Row(children: [
                        Container(width: 70, height: 70, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle), child: const Icon(Icons.person, color: Colors.white, size: 40)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          if (email.isNotEmpty) Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
                          const SizedBox(height: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE7F1F0), borderRadius: BorderRadius.circular(20)), child: const Text('User', style: TextStyle(color: AppColors.teal, fontSize: 11, fontWeight: FontWeight.w700))),
                        ])),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // stat row
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x140E5C5C), blurRadius: 16)]),
                      child: Row(children: [
                        _stat('Total', total, AppColors.blue, AppColors.blueBg, Icons.local_shipping),
                        _stat('Running', run, AppColors.green, AppColors.greenBg, Icons.play_arrow),
                        _stat('Idle', idle, AppColors.orange, AppColors.orangeBg, Icons.pause),
                        _stat('Offline', off, AppColors.red, AppColors.redBg, Icons.stop),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // plan banner (tap to view account details)
                    GestureDetector(
                      onTap: _showAccountInfo,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.teal, AppColors.teal2]), borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.9), shape: BoxShape.circle), child: const Icon(Icons.workspace_premium, color: Colors.white)),
                          const SizedBox(width: 13),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Current Plan', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                            Text(_plan, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                            Text(_valid, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ])),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // menu
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x140E5C5C), blurRadius: 16)]),
                      child: Column(children: [
                        _menu(Icons.person_outline, 'Account Information', 'View your account details', onTap: _showAccountInfo),
                        _menu(Icons.business_outlined, 'Company Information', 'Manage company details'),
                        _menu(Icons.group_outlined, 'User Management', 'Manage users and permissions'),
                        KeyedSubtree(key: TourKeys.profileStore, child: _menu(Icons.storefront, 'Store & Services', 'Buy GPS, renew plans, request services', onTap: () { Haptics.light(); Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreScreen())); })),
                        _menu(Icons.notifications_none, 'Notification Settings', 'Manage alert preferences', onTap: () { Haptics.light(); Navigator.pushNamed(context, '/notification-settings'); }),
                        _menu(Icons.shield_outlined, 'Security', 'Change password and security'),
                        _menu(Icons.help_outline, 'Help & Support', 'FAQs, guides and contact support'),
                        _menu(Icons.info_outline, 'About Bharat GPS Tracker', 'App version and information', last: true, onTap: _showAbout),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    // logout
                    GestureDetector(
                      onTap: () { Haptics.medium(); _logout(); },
                      child: Container(
                        padding: const EdgeInsets.all(17),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x140E5C5C), blurRadius: 16)]),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.logout, color: AppColors.red, size: 20),
                          SizedBox(width: 9),
                          Text('Logout', style: TextStyle(color: AppColors.red, fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Bharat GPS Tracker · v1.0.0', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
              ],
            ),
          ),
        ]),
    );
  }

  Widget _stat(String label, int val, Color color, Color bg, IconData ic) => Expanded(
        child: Column(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(ic, color: color, size: 19)),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.ink2)),
          Text('$val', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _menu(IconData ic, String title, String sub, {bool last = false, VoidCallback? onTap}) => InkWell(
        onTap: onTap ?? () { Haptics.light(); _soon(title); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(children: [
            SizedBox(width: 34, child: Icon(ic, color: AppColors.teal, size: 22)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              Text(sub, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2)),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ]),
        ),
      );
}
