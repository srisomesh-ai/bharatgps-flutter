import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Shown once after install, before login. A 5-card welcome carousel.
class WelcomeCarousel extends StatefulWidget {
  final VoidCallback onDone;
  const WelcomeCarousel({super.key, required this.onDone});

  static const _seenKey = 'seen_welcome_v1';

  static Future<bool> alreadySeen() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_seenKey, true);
  }

  @override
  State<WelcomeCarousel> createState() => _WelcomeCarouselState();
}

class _WelcomeCarouselState extends State<WelcomeCarousel> {
  final _pc = PageController();
  int _i = 0;

  static const _slides = [
    {'badge': 'NEW APP', 'icon': Icons.satellite_alt, 'title': 'Welcome to BharatGPS', 'text': 'A fresh, faster way to track and manage your vehicles. Let\'s show you what\'s new.'},
    {'badge': '', 'icon': Icons.my_location, 'title': 'Live Tracking', 'text': 'See all your vehicles in real-time on the map — with smooth movement, speed and direction.'},
    {'badge': '', 'icon': Icons.notifications_active, 'title': 'Smart Alerts', 'text': 'Get instant alerts for over-speed, engine on/off, power cut, and geofence entry & exit.'},
    {'badge': '', 'icon': Icons.route, 'title': 'Trips & History', 'text': 'Review every trip with distance, stops and playback. Tap a trip to see its route on the map.'},
    {'badge': '', 'icon': Icons.storefront, 'title': 'Store & Renew', 'text': 'Buy new GPS devices, request services, and renew your plan — pay instantly via UPI.'},
  ];

  Future<void> _finish() async {
    await WelcomeCarousel.markSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, Color(0xFF0A4444)])),
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _i = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if ((s['badge'] as String).isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(20)),
                          child: Text(s['badge'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.15))),
                        child: Icon(s['icon'] as IconData, size: 58, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      Text(s['text'] as String, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14.5, height: 1.6), textAlign: TextAlign.center),
                    ]),
                  );
                },
              ),
            ),
            // dots
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_slides.length, (i) {
              final on = i == _i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 24 : 8, height: 8,
                decoration: BoxDecoration(color: on ? AppColors.amber : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
              );
            })),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Haptics.light();
                    if (last) {
                      _finish();
                    } else {
                      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(last ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Spotlight feature tour shown after first login. It drives the MainShell to
/// switch tabs as it explains each one, and points a down-arrow at the active
/// bottom-nav item. Self-contained: the only hook into existing code is the
/// onGoToTab callback (the shell already had a goTo method).
class FeatureTour extends StatefulWidget {
  final VoidCallback onDone;
  final ValueChanged<int> onGoToTab; // ask the shell to switch tab
  const FeatureTour({super.key, required this.onDone, required this.onGoToTab});

  static const _seenKey = 'seen_tour_v1';

  // the shell pings this when the user taps a nav tab, so the tour can advance
  static final ValueNotifier<int> navTapped = ValueNotifier<int>(-1);

  static Future<bool> alreadySeen() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_seenKey) ?? false;
  }

  static Future<void> markSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_seenKey, true);
  }

  /// reset so it can be replayed from Profile
  static Future<void> replay() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_seenKey, false);
  }

  @override
  State<FeatureTour> createState() => _FeatureTourState();
}

class _FeatureTourState extends State<FeatureTour> {
  int _i = 0;

  // Each step belongs to a page (tab). Steps with the SAME tab are shown while
  // on that page (multiple key points). The last step on a page sets
  // tapToAdvance=true → user must tap the highlighted nav tab to continue.
  // 0=Dashboard 1=Activity 2=Map 3=Alerts 4=Profile
  static const _stops = [
    // DASHBOARD
    {'tab': 0, 'icon': Icons.dashboard, 'title': 'Dashboard', 'text': 'This is your home base — a quick overview of your entire fleet.'},
    {'tab': 0, 'icon': Icons.filter_alt, 'title': 'Quick Filters', 'text': 'The stat cards (Total, Running, Idle, Offline) are tappable — tap one to filter the vehicle list instantly.'},
    {'tab': 0, 'icon': Icons.directions_car, 'title': 'Vehicle List', 'text': 'Tap any vehicle in the list to jump straight to it on the live map.', 'tapToAdvance': true, 'nextTab': 1},
    // ACTIVITY
    {'tab': 1, 'icon': Icons.bar_chart, 'title': 'Fleet Activity', 'text': 'See your fleet status breakdown — how many are Running, Idle or Offline at a glance.'},
    {'tab': 1, 'icon': Icons.show_chart, 'title': 'Distance & Attention', 'text': 'Total fleet distance today, plus which vehicles need attention.', 'tapToAdvance': true, 'nextTab': 2},
    // MAP
    {'tab': 2, 'icon': Icons.map, 'title': 'Live Map', 'text': 'All your vehicles in real-time with smooth movement and direction. Tap a vehicle to see its details.'},
    {'tab': 2, 'icon': Icons.layers, 'title': 'Map Types', 'text': 'Top-left: switch between Map, Satellite and Hybrid views.'},
    {'tab': 2, 'icon': Icons.share, 'title': 'Share Live Tracking', 'text': 'Right-side Share button: send a live tracking link via WhatsApp — it expires automatically.'},
    {'tab': 2, 'icon': Icons.fmd_good, 'title': 'Geofence & Controls', 'text': 'Right-side buttons: locate, show/hide names, compass, and the Geofence toggle to view your zones.', 'tapToAdvance': true, 'nextTab': 3},
    // ALERTS
    {'tab': 3, 'icon': Icons.notifications, 'title': 'Alerts', 'text': 'All your active alerts and their history. Get notified for speed, engine, power cut and more.'},
    {'tab': 3, 'icon': Icons.add_alert, 'title': 'Create & Geofence', 'text': 'Bottom-right: the Create button makes new alerts, and the Geofence button sets up map zones.', 'tapToAdvance': true, 'nextTab': 4},
    // PROFILE
    {'tab': 4, 'icon': Icons.person, 'title': 'Profile', 'text': 'Your account, plan and days left.'},
    {'tab': 4, 'icon': Icons.storefront, 'title': 'Store & Renew', 'text': 'Open Store & Services to buy GPS devices, request services, and renew your plan via UPI.'},
    {'tab': 4, 'icon': Icons.help_center, 'title': 'Replay Anytime', 'text': 'Tap "How to Use" here anytime to replay this tour. You\'re all set — happy tracking! 🛰', 'last': true},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onGoToTab(_stops[0]['tab'] as int);
    });
    FeatureTour.navTapped.addListener(_onNavTap);
  }

  void _onNavTap() {
    final tapped = FeatureTour.navTapped.value;
    if (tapped < 0) return;
    final s = _stops[_i];
    final tapToAdvance = (s['tapToAdvance'] as bool?) ?? false;
    // if the user tapped the tab we asked them to, advance the tour
    if (tapToAdvance && tapped == (s['nextTab'] as int)) {
      _advance();
    }
  }

  @override
  void dispose() {
    FeatureTour.navTapped.removeListener(_onNavTap);
    super.dispose();
  }

  Future<void> _finish() async {
    await FeatureTour.markSeen();
    widget.onDone();
  }

  void _advance() {
    Haptics.light();
    if (_i < _stops.length - 1) {
      final nextTab = _stops[_i + 1]['tab'] as int;
      setState(() => _i++);
      widget.onGoToTab(nextTab);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stops[_i];
    final last = (s['last'] as bool?) ?? false;
    final tapToAdvance = (s['tapToAdvance'] as bool?) ?? false;
    final tab = s['tab'] as int;
    final screenW = MediaQuery.of(context).size.width;
    final itemCenterX = screenW * (tab + 0.5) / 5;
    // step number within the current page (for "1 of N" feel) — simple global dots

    return Stack(children: [
      // dim only the area ABOVE the bottom nav, so the real nav stays tappable
      Positioned(
        top: 0, left: 0, right: 0, bottom: 64,
        child: Material(
          color: Colors.black.withOpacity(0.74),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      ),

      // explanation card — sits just above the nav bar
      Positioned(
        left: 20, right: 20, bottom: 76,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 30)]),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(s['icon'] as IconData, color: AppColors.teal, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s['title'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 11),
            Text(s['text'] as String, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.5)),
            const SizedBox(height: 15),
            if (tapToAdvance) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(11), border: Border.all(color: AppColors.amber, width: 1.2)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.touch_app, size: 17, color: AppColors.amber),
                  const SizedBox(width: 7),
                  Text('Tap the ${_tabName(s['nextTab'] as int)} tab below', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFB8801A))),
                ]),
              ),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: _advance, child: const Text('or tap here to continue', style: TextStyle(fontSize: 11.5, color: AppColors.ink2)))),
            ] else
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: List.generate(_stops.length, (i) {
                  final on = i == _i;
                  return Container(margin: const EdgeInsets.only(right: 3), width: on ? 14 : 5, height: 5, decoration: BoxDecoration(color: on ? AppColors.teal : AppColors.line, borderRadius: BorderRadius.circular(3)));
                })),
                ElevatedButton(
                  onPressed: _advance,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                  child: Text(last ? 'Done' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
          ]),
        ),
      ),

      // bouncing arrow + highlight ring ON the nav item the user should tap
      if (tapToAdvance) ...[
        Positioned(bottom: 60, left: itemCenterX - 17, child: const _BounceArrow()),
        Positioned(
          bottom: 4, left: itemCenterX - 30,
          child: IgnorePointer(
            child: Container(
              width: 60, height: 56,
              decoration: BoxDecoration(border: Border.all(color: AppColors.amber, width: 2.5), borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
      ],
    ]);
  }

  String _tabName(int i) => const ['Dashboard', 'Activity', 'Map', 'Alerts', 'Profile'][i];
}

/// A small bouncing down-arrow used to point at the nav item.
class _BounceArrow extends StatefulWidget {
  const _BounceArrow();
  @override
  State<_BounceArrow> createState() => _BounceArrowState();
}

class _BounceArrowState extends State<_BounceArrow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _c.value * 8),
        child: const Icon(Icons.keyboard_double_arrow_down, color: AppColors.amber, size: 34),
      ),
    );
  }
}
