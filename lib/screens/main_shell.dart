import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'activity_screen.dart';
import 'map_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import 'onboarding.dart';

/// Holds all 5 main tabs alive in an IndexedStack so switching tabs is instant
/// (no rebuild, no flicker). The bottom nav only changes the index.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  // lets any screen switch tab: MainShell.of(context)?.goTo(2)
  static _MainShellState? of(BuildContext context) => context.findAncestorStateOfType<_MainShellState>();

  // a vehicle id the map should focus on when it next becomes visible
  static final ValueNotifier<dynamic> mapFocusId = ValueNotifier<dynamic>(null);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  DateTime? _lastBack;
  bool _showTour = false;

  final _pages = const [
    DashboardScreen(),
    ActivityScreen(),
    MapScreen(),
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _maybeShowTour();
  }

  Future<void> _maybeShowTour() async {
    final seen = await FeatureTour.alreadySeen();
    if (!seen && mounted) {
      // small delay so the first screen is built behind the tour
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _showTour = true);
    }
  }

  void goTo(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (_showTour) FeatureTour.navTapped.value = i;
  }

  // switch to the Map tab and tell it which vehicle to focus
  void focusVehicleOnMap(dynamic deviceId) {
    MainShell.mapFocusId.value = null; // reset so the same id re-fires
    MainShell.mapFocusId.value = deviceId;
    setState(() => _index = 2);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // back from a non-dashboard tab -> go to dashboard
        if (_index != 0) {
          setState(() => _index = 0);
          return;
        }
        // on dashboard: double-back to exit
        final now = DateTime.now();
        if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
          _lastBack = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Stack(children: [
        Scaffold(
          body: IndexedStack(index: _index, children: _pages),
          bottomNavigationBar: _BottomBar(current: _index, onTap: goTo),
        ),
        if (_showTour)
          FeatureTour(
            onDone: () => setState(() => _showTour = false),
            onGoToTab: (i) => setState(() => _index = i),
          ),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.current, required this.onTap});

  static const _labels = ['Dashboard', 'Activity', 'Map', 'Alerts', 'Profile'];
  static const _icons = [
    Icons.home_outlined,
    Icons.bar_chart_outlined,
    Icons.map_outlined,
    Icons.notifications_none,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: List.generate(5, (i) {
          final on = i == current;
          return Expanded(
            child: InkWell(
              onTap: () { Haptics.light(); onTap(i); },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icons[i], size: 21, color: on ? AppColors.teal : AppColors.muted),
                  const SizedBox(height: 3),
                  Text(_labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: on ? AppColors.teal : AppColors.muted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
