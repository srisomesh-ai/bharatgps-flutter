import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Lightweight branded loaders (one AnimationController each). Use per task:
/// - SatelliteLoader  -> map ("Locating vehicles…")
/// - RouteLoader      -> trips ("Loading trips…")
/// - SpeedoLoader     -> reports ("Building report…")
/// - SignalLoader     -> dashboard / alerts ("Loading…")

class _Spin extends StatefulWidget {
  final Widget Function(double t) builder;
  final Duration duration;
  const _Spin({required this.builder, this.duration = const Duration(milliseconds: 1400)});
  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (_, __) => widget.builder(_c.value));
}

Widget _wrap(Widget anim, String label) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        anim,
        const SizedBox(height: 18),
        Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.teal)),
      ]),
    );

// ===== INLINE: small road loader for buttons (a moving dot along a road) =====
class RouteMiniLoader extends StatelessWidget {
  final double width;
  final double height;
  final Color? color;
  const RouteMiniLoader({super.key, this.width = 26, this.height = 14, this.color});
  @override
  Widget build(BuildContext context) {
    return _Spin(
      duration: const Duration(milliseconds: 1200),
      builder: (t) => SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _RouteMiniPainter(t, color ?? AppColors.teal)),
      ),
    );
  }
}

class _RouteMiniPainter extends CustomPainter {
  final double t;
  final Color color;
  _RouteMiniPainter(this.t, this.color);
  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    // road base line
    c.drawLine(Offset(2, y), Offset(s.width - 2, y),
        Paint()..color = color.withOpacity(0.22)..strokeWidth = 3..strokeCap = StrokeCap.round);
    // dashed centre markings (static)
    final dash = Paint()..color = color.withOpacity(0.4)..strokeWidth = 1.4..strokeCap = StrokeCap.round;
    for (double x = 4; x < s.width - 4; x += 7) {
      c.drawLine(Offset(x, y), Offset(x + 3, y), dash);
    }
    // moving truck dot
    final x = 2 + (s.width - 4) * t;
    c.drawCircle(Offset(x, y), 4.2, Paint()..color = color);
    c.drawCircle(Offset(x, y), 2.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RouteMiniPainter old) => old.t != t;
}

// ===== MAP: orbiting satellites around a globe =====
class SatelliteLoader extends StatelessWidget {
  final String label;
  const SatelliteLoader({super.key, this.label = 'Locating vehicles…'});
  @override
  Widget build(BuildContext context) {
    return _wrap(
      _Spin(
        duration: const Duration(milliseconds: 2000),
        builder: (t) => SizedBox(width: 86, height: 86, child: CustomPaint(painter: _SatellitePainter(t))),
      ),
      label,
    );
  }
}

class _SatellitePainter extends CustomPainter {
  final double t;
  _SatellitePainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.line;
    // two orbits
    c.drawCircle(ctr, 40, orbit);
    c.drawCircle(ctr, 28, orbit);
    // globe
    c.drawCircle(ctr, 14, Paint()..color = AppColors.teal);
    c.drawCircle(ctr + const Offset(-3, -3), 5, Paint()..color = AppColors.teal2);
    // satellites
    final a1 = t * 2 * math.pi;
    final a2 = -t * 2 * math.pi * 1.6;
    final p1 = ctr + Offset(math.cos(a1) * 40, math.sin(a1) * 40);
    final p2 = ctr + Offset(math.cos(a2) * 28, math.sin(a2) * 28);
    final sat = Paint()..color = AppColors.amber;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p1, width: 9, height: 9), const Radius.circular(2)), sat);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p2, width: 7, height: 7), const Radius.circular(2)), Paint()..color = AppColors.blue);
  }

  @override
  bool shouldRepaint(_SatellitePainter old) => old.t != t;
}

// ===== TRIPS: route drawing toward a destination =====
class RouteLoader extends StatelessWidget {
  final String label;
  const RouteLoader({super.key, this.label = 'Loading trips…'});
  @override
  Widget build(BuildContext context) {
    return _wrap(
      _Spin(
        duration: const Duration(milliseconds: 1800),
        builder: (t) => SizedBox(width: 120, height: 60, child: CustomPaint(painter: _RoutePainter(t))),
      ),
      label,
    );
  }
}

class _RoutePainter extends CustomPainter {
  final double t;
  _RoutePainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final path = Path()
      ..moveTo(8, s.height - 10)
      ..quadraticBezierTo(s.width * 0.35, -6, s.width * 0.55, s.height * 0.5)
      ..quadraticBezierTo(s.width * 0.72, s.height * 0.92, s.width - 10, 12);
    // background route
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = AppColors.line..strokeCap = StrokeCap.round);
    // animated draw
    final metric = path.computeMetrics().first;
    final prog = (t / 0.75).clamp(0.0, 1.0);
    final draw = metric.extractPath(0, metric.length * prog);
    c.drawPath(draw, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = AppColors.teal..strokeCap = StrokeCap.round);
    // moving truck dot at the tip
    final tan = metric.getTangentForOffset(metric.length * prog);
    if (tan != null) {
      c.drawCircle(tan.position, 6, Paint()..color = AppColors.teal);
      c.drawCircle(tan.position, 3, Paint()..color = Colors.white);
    }
    // destination pin
    c.drawCircle(Offset(s.width - 10, 12), 4, Paint()..color = AppColors.red);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.t != t;
}

// ===== REPORTS: speedometer needle sweep =====
class SpeedoLoader extends StatelessWidget {
  final String label;
  const SpeedoLoader({super.key, this.label = 'Building report…'});
  @override
  Widget build(BuildContext context) {
    return _wrap(
      _Spin(
        duration: const Duration(milliseconds: 1500),
        builder: (t) => SizedBox(width: 96, height: 60, child: CustomPaint(painter: _SpeedoPainter(t))),
      ),
      label,
    );
  }
}

class _SpeedoPainter extends CustomPainter {
  final double t;
  _SpeedoPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height - 6);
    final r = s.width / 2 - 6;
    // dial arc
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: ctr, radius: r);
    arc.shader = const LinearGradient(colors: [AppColors.teal, AppColors.amber, AppColors.red]).createShader(rect);
    c.drawArc(rect, math.pi, math.pi, false, arc);
    // needle: swing -80..+80 deg
    final swing = math.sin(t * 2 * math.pi); // -1..1
    final ang = math.pi * 1.5 + swing * (80 * math.pi / 180);
    final tip = ctr + Offset(math.cos(ang) * (r - 6), math.sin(ang) * (r - 6));
    c.drawLine(ctr, tip, Paint()..color = AppColors.red..strokeWidth = 3..strokeCap = StrokeCap.round);
    c.drawCircle(ctr, 6, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_SpeedoPainter old) => old.t != t;
}

// ===== DASHBOARD / ALERTS: live signal waves =====
class SignalLoader extends StatelessWidget {
  final String label;
  const SignalLoader({super.key, this.label = 'Loading…'});
  @override
  Widget build(BuildContext context) {
    return _wrap(
      _Spin(
        duration: const Duration(milliseconds: 1800),
        builder: (t) => SizedBox(width: 80, height: 80, child: CustomPaint(painter: _SignalPainter(t))),
      ),
      label,
    );
  }
}

class _SignalPainter extends CustomPainter {
  final double t;
  _SignalPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    for (int i = 0; i < 3; i++) {
      final p = ((t + i / 3) % 1.0);
      final radius = 8 + p * 32;
      final op = (1 - p).clamp(0.0, 1.0);
      c.drawCircle(ctr, radius, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.green.withOpacity(op * 0.8));
    }
    c.drawCircle(ctr, 8, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(_SignalPainter old) => old.t != t;
}
