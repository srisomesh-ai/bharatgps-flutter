import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatelessWidget {
  final int current; // 0 dashboard, 1 activity, 2 map, 3 alerts, 4 profile
  const BottomNav({super.key, required this.current});

  static const _routes = ['/dashboard', '/activity', '/map', '/alerts', '/profile'];
  static const _labels = ['Dashboard', 'Activity', 'Map', 'Alerts', 'Profile'];
  static const _icons = [
    Icons.home_outlined,
    Icons.bar_chart_outlined,
    Icons.map_outlined,
    Icons.notifications_none,
    Icons.person_outline,
  ];

  void _go(BuildContext context, int i) {
    if (i == current) return;
    Navigator.pushReplacementNamed(context, _routes[i]);
  }

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
              onTap: () => _go(context, i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icons[i], size: 21, color: on ? AppColors.teal : AppColors.muted),
                  const SizedBox(height: 3),
                  Text(_labels[i],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: on ? AppColors.teal : AppColors.muted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Reusable vehicle icon (falls back to a truck glyph)
Widget vehicleThumb(String? iconUrl, {double size = 42}) {
  if (iconUrl != null && iconUrl.isNotEmpty) {
    return Image.network(iconUrl, width: size, height: size * 0.76, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.local_shipping, size: size * 0.7, color: AppColors.teal));
  }
  return Icon(Icons.local_shipping, size: size * 0.7, color: AppColors.teal);
}
