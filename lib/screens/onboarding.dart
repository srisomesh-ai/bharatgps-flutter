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

  // tab: which bottom-nav index this step relates to (0=Dashboard,1=Activity,
  // 2=Map,3=Alerts,4=Profile). arrow=true points a down-arrow at that nav item.
  static const _stops = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'text': 'Your whole fleet at a glance. Tap the stat cards to filter Running, Idle or Offline vehicles.', 'tab': 0, 'arrow': true},
    {'icon': Icons.bar_chart, 'title': 'Fleet Activity', 'text': 'See your fleet status breakdown and total distance covered today.', 'tab': 1, 'arrow': true},
    {'icon': Icons.map, 'title': 'Live Map', 'text': 'Track all your vehicles in real-time. Tap a vehicle for its speed, engine status and expiry. Use the Share button to send a live link.', 'tab': 2, 'arrow': true},
    {'icon': Icons.notifications, 'title': 'Alerts & Geofence', 'text': 'Create alerts for speed, engine, power cut, and geofence entry/exit. Set up geofence zones here too.', 'tab': 3, 'arrow': true},
    {'icon': Icons.person, 'title': 'Profile & Store', 'text': 'Manage your account, buy GPS devices, renew your plan, and replay this tour from "How to Use".', 'tab': 4, 'arrow': true},
    {'icon': Icons.celebration, 'title': 'You\'re all set!', 'text': 'That\'s the tour. Replay it anytime from Profile → How to Use. Happy tracking! 🛰', 'tab': 2, 'arrow': false},
  ];

  @override
  void initState() {
    super.initState();
    // move to the first step's tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onGoToTab(_stops[0]['tab'] as int);
    });
  }

  Future<void> _finish() async {
    await FeatureTour.markSeen();
    widget.onDone();
  }

  void _next() {
    Haptics.light();
    if (_i < _stops.length - 1) {
      setState(() => _i++);
      widget.onGoToTab(_stops[_i]['tab'] as int);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stops[_i];
    final last = _i == _stops.length - 1;
    final showArrow = s['arrow'] as bool;
    final tab = s['tab'] as int;
    final screenW = MediaQuery.of(context).size.width;
    // 5 nav items evenly spaced — center of each item
    final itemCenterX = screenW * (tab + 0.5) / 5;

    return Material(
      color: Colors.black.withOpacity(0.78),
      child: SafeArea(
        child: Stack(children: [
          // Skip
          Align(
            alignment: Alignment.topRight,
            child: TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
          ),

          // explanation card (sits above the nav so the arrow can point down to it)
          Positioned(
            left: 22, right: 22, bottom: 96,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30)]),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(s['icon'] as IconData, color: AppColors.teal, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 12),
                Text(s['text'] as String, style: const TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.5)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: List.generate(_stops.length, (i) {
                    final on = i == _i;
                    return Container(
                      margin: const EdgeInsets.only(right: 5),
                      width: on ? 18 : 6, height: 6,
                      decoration: BoxDecoration(color: on ? AppColors.teal : AppColors.line, borderRadius: BorderRadius.circular(3)),
                    );
                  })),
                  ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                    child: Text(last ? 'Done' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),

          // down-arrow pointing at the active bottom-nav item
          if (showArrow)
            Positioned(
              bottom: 60,
              left: itemCenterX - 16,
              child: const _BounceArrow(),
            ),

          // highlight ring around the active nav item
          if (showArrow)
            Positioned(
              bottom: 2,
              left: itemCenterX - 30,
              child: Container(
                width: 60, height: 56,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.amber, width: 2.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
        ]),
      ),
    );
  }
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
