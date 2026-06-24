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
