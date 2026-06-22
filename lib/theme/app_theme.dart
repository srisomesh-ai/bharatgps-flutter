import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide haptic feedback helpers. Use these on taps so the app feels tactile.
class Haptics {
  /// Light tap — for nav switches, list taps, chip selections.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap — for primary action buttons (Navigate, Playback, Create).
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy/selection — for important confirms (Engine cut-off, delete).
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection click — subtle, for toggles and radio choices.
  static void select() => HapticFeedback.selectionClick();
}

class AppColors {
  static const teal = Color(0xFF0E5C5C);
  static const teal2 = Color(0xFF137272);
  static const amber = Color(0xFFF5A623);
  static const bg = Color(0xFFEFF3F2);
  static const ink = Color(0xFF16201F);
  static const ink2 = Color(0xFF55676A);
  static const muted = Color(0xFF8A9A98);
  static const line = Color(0xFFE9EFEE);
  static const green = Color(0xFF27AE60);
  static const orange = Color(0xFFF39C12);
  static const red = Color(0xFFE74C3C);
  static const blue = Color(0xFF2E86DE);
  static const violet = Color(0xFF6C5CE7);
  static const greenBg = Color(0xFFE7F7EC);
  static const orangeBg = Color(0xFFFDF1DE);
  static const redBg = Color(0xFFFCEAE8);
  static const blueBg = Color(0xFFE7F1FC);
  static const violetBg = Color(0xFFF0F0FB);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.teal,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}

// status helpers
String stateOf(String? online, num? speed) {
  if (online == 'offline' || online == null) return 'of';
  if (online == 'online') return 'rn';
  if (online == 'ack') return 'id';
  return (speed ?? 0) > 3 ? 'rn' : 'id';
}

const stateLabels = {'rn': 'Running', 'id': 'Idle', 'of': 'Offline'};

Color stateColor(String s) {
  switch (s) {
    case 'rn':
      return AppColors.green;
    case 'id':
      return AppColors.orange;
    default:
      return AppColors.red;
  }
}

Color stateBg(String s) {
  switch (s) {
    case 'rn':
      return AppColors.greenBg;
    case 'id':
      return AppColors.orangeBg;
    default:
      return AppColors.redBg;
  }
}

String agoText(dynamic ts) {
  if (ts == null) return '—';
  DateTime? t;
  if (ts is num) {
    t = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
  } else {
    t = DateTime.tryParse(ts.toString().replaceFirst(' ', 'T'));
  }
  if (t == null) return ts.toString();
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 60) return 'Just now';
  if (s < 3600) return '${(s / 60).floor()} min ago';
  if (s < 86400) return '${(s / 3600).floor()} hr ago';
  final d = (s / 86400).floor();
  return '$d day${d > 1 ? 's' : ''} ago';
}

// parse server flag "true"/"false"/bool/null
bool? tBool(dynamic v) {
  if (v == true || v == false) return v as bool;
  if (v == null) return null;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1' || s == 'on') return true;
  if (s == 'false' || s == '0' || s == 'off') return false;
  return null;
}
