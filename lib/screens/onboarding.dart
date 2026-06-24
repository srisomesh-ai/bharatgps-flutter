import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'tour_keys.dart';

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

class _TourStep {
  final int tab;
  final GlobalKey? key;
  final String emoji;
  final String title;
  final String text;
  final bool round;
  const _TourStep({required this.tab, this.key, required this.emoji, required this.title, required this.text, this.round = false});
}

class _FeatureTourState extends State<FeatureTour> {
  int _i = 0;
  Rect? _targetRect;

  late final List<_TourStep> _steps = [
    _TourStep(tab: 0, key: null, emoji: '🏠', title: 'Dashboard', text: 'Your home base — a live overview of your entire fleet at a glance.'),
    _TourStep(tab: 0, key: TourKeys.dashStats, emoji: '🎯', title: 'Quick Filters', text: 'Tap a card to filter Running, Idle or Offline vehicles instantly.'),
    _TourStep(tab: 0, key: TourKeys.dashList, emoji: '🚚', title: 'Vehicle List', text: 'Tap any vehicle to jump straight to it on the live map.'),
    _TourStep(tab: 1, key: TourKeys.activityStatus, emoji: '📊', title: 'Fleet Activity', text: 'Your fleet status breakdown and total distance covered today.'),
    _TourStep(tab: 2, key: null, emoji: '🗺️', title: 'Live Map', text: 'All your vehicles update here in real-time with direction and speed. Tap a vehicle for full details.'),
    _TourStep(tab: 2, key: TourKeys.mapTypes, emoji: '🗂️', title: 'Map Type', text: 'Switch between Map, Satellite and Hybrid views.'),
    _TourStep(tab: 2, key: TourKeys.mapLocate, emoji: '📍', title: 'Locate', text: 'Center the map on your vehicles.', round: true),
    _TourStep(tab: 2, key: TourKeys.mapShare, emoji: '📤', title: 'Share Tracking', text: 'Send a live tracking link on WhatsApp — it expires automatically.', round: true),
    _TourStep(tab: 2, key: TourKeys.mapNames, emoji: '🏷️', title: 'Names', text: 'Show or hide vehicle name labels.', round: true),
    _TourStep(tab: 2, key: TourKeys.mapGeofence, emoji: '▦', title: 'Geofence Zones', text: 'Toggle your saved geofence zones on the map.', round: true),
    _TourStep(tab: 3, key: null, emoji: '🔔', title: 'Alerts', text: 'All your alerts and their history. Get notified for speed, engine, power cut and more.'),
    _TourStep(tab: 3, key: TourKeys.alertsGeofence, emoji: '▦', title: 'Geofence', text: 'Create map zones to alert on entry or exit.'),
    _TourStep(tab: 3, key: TourKeys.alertsCreate, emoji: '➕', title: 'Create Alert', text: 'Make a new alert — speed, engine, power cut, geofence and more.'),
    _TourStep(tab: 4, key: null, emoji: '👤', title: 'Profile', text: 'Your account, plan and days remaining.'),
    _TourStep(tab: 4, key: TourKeys.profileStore, emoji: '🛒', title: 'Store & Renew', text: 'Buy GPS devices, request services, and renew your plan via UPI.'),
    _TourStep(tab: 4, key: null, emoji: '🎉', title: "You're all set!", text: 'Replay this tour anytime from Profile → How to Use. Happy tracking!'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToStep(0));
  }

  Future<void> _finish() async {
    await FeatureTour.markSeen();
    widget.onDone();
  }

  Future<void> _goToStep(int i) async {
    widget.onGoToTab(_steps[i].tab);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    _measure();
  }

  void _measure() {
    final key = _steps[_i].key;
    Rect? rect;
    if (key != null) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          rect = box.localToGlobal(Offset.zero) & box.size;
        }
      }
    }
    setState(() => _targetRect = rect);
  }

  void _next() {
    Haptics.light();
    if (_i < _steps.length - 1) {
      setState(() { _i++; });
      _goToStep(_i);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_i > 0) {
      Haptics.light();
      setState(() { _i--; });
      _goToStep(_i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_i];
    final last = _i == _steps.length - 1;
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final r = _targetRect;
    const pad = 7.0;
    // when no target, use an off-screen tiny rect (centered intro card)
    final hole = (r == null)
        ? Rect.fromLTWH(size.width / 2 - 0.5, -60, 1, 1)
        : Rect.fromLTRB(r.left - pad, r.top - pad, r.right + pad, r.bottom + pad);
    final hasTarget = r != null;

    // tooltip geometry (matches HTML: width 210, nub 14)
    const tipW = 220.0;
    final tipH = 128.0;
    // decide tooltip side
    String side; // 'left','below','above','center'
    if (!hasTarget) {
      side = 'center';
    } else if (hole.right > size.width - 70) {
      side = 'left'; // right-edge map controls -> tooltip to the left
    } else if (size.height - hole.bottom > tipH + 30) {
      side = 'below';
    } else {
      side = 'above';
    }

    double tipLeft, tipTop;
    double nubLeft = 0, nubTop = 0; bool nubShow = true;
    switch (side) {
      case 'left':
        tipLeft = hole.left - tipW - 16;
        tipTop = hole.center.dy - tipH / 2;
        nubLeft = tipW - 7; nubTop = tipH / 2 - 7; // nub on right edge of tip
        break;
      case 'below':
        tipLeft = hole.center.dx - tipW / 2;
        tipTop = hole.bottom + 16;
        nubTop = -7;
        break;
      case 'above':
        tipLeft = hole.center.dx - tipW / 2;
        tipTop = hole.top - tipH - 16;
        nubTop = tipH - 7;
        break;
      default: // center
        tipLeft = size.width / 2 - tipW / 2;
        tipTop = size.height / 2 - tipH / 2;
        nubShow = false;
    }
    // clamp horizontally
    if (tipLeft < 12) tipLeft = 12;
    if (tipLeft + tipW > size.width - 12) tipLeft = size.width - 12 - tipW;
    if (tipTop < topPad + 44) tipTop = topPad + 44;
    // nub x for below/above (point at target center relative to tip)
    if (side == 'below' || side == 'above') {
      nubLeft = (hole.center.dx - tipLeft - 7).clamp(16.0, tipW - 30.0);
    }

    return Stack(children: [
      // animated dimmed layer with a moving hole
      Positioned.fill(
        child: TweenAnimationBuilder<Rect?>(
          tween: RectTween(begin: hole, end: hole),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          builder: (_, animRect, __) => CustomPaint(painter: _HolePainter(hasTarget ? animRect : null, s.round)),
        ),
      ),
      // animated amber ring
      if (hasTarget)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          left: hole.left, top: hole.top, width: hole.width, height: hole.height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.amber, width: 2.5),
                borderRadius: BorderRadius.circular(s.round ? hole.width : 14),
                boxShadow: [BoxShadow(color: AppColors.amber.withOpacity(0.5), blurRadius: 18)],
              ),
            ),
          ),
        ),
      // Skip pill (top-right, matches HTML)
      Positioned(
        top: topPad + 12, right: 16,
        child: GestureDetector(
          onTap: _finish,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
            child: const Text('Skip ✕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ),
      ),
      // animated tooltip with nub
      AnimatedPositioned(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        left: tipLeft, top: tipTop,
        child: SizedBox(
          width: tipW,
          child: Stack(clipBehavior: Clip.none, children: [
            // nub (rotated square) — drawn first, behind the card edge
            if (nubShow)
              Positioned(
                left: nubLeft, top: nubTop,
                child: Transform.rotate(
                  angle: 0.785398, // 45deg
                  child: Container(width: 14, height: 14, color: Colors.white),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x52000000), blurRadius: 30, offset: Offset(0, 10))]),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(s.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink))),
                ]),
                const SizedBox(height: 4),
                Text(s.text, style: const TextStyle(fontSize: 11.5, color: AppColors.ink2, height: 1.5)),
                const SizedBox(height: 11),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${_i + 1} / ${_steps.length}', style: const TextStyle(fontSize: 10, color: Color(0xFF9AAEAE), fontWeight: FontWeight.w700)),
                  Row(children: [
                    if (_i > 0)
                      GestureDetector(onTap: _prev, child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6), decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(9)), child: const Text('Back', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink2)))),
                    const SizedBox(width: 6),
                    GestureDetector(onTap: _next, child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6), decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(9)), child: Text(last ? 'Done' : 'Next', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)))),
                  ]),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Paints a full-screen dim with a rounded/circular transparent hole.
class _HolePainter extends CustomPainter {
  final Rect? hole;
  final bool round;
  _HolePainter(this.hole, this.round);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = const Color(0xBD091615); // rgba(9,22,21,.74)
    if (hole == null) {
      canvas.drawRect(Offset.zero & size, dim);
      return;
    }
    final full = Path()..addRect(Offset.zero & size);
    final cut = round
        ? (Path()..addOval(hole!))
        : (Path()..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(12))));
    canvas.drawPath(Path.combine(PathOperation.difference, full, cut), dim);
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole || old.round != round;
}
