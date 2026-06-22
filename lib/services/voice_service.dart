import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../screens/main_shell.dart';

/// Voice commands via NATIVE Android speech (platform channel) — no package,
/// so it never conflicts with Firebase. Mirrors the proven voice-test approach.
class VoiceService {
  static const _channel = MethodChannel('bharatgps/voice');
  static bool _wired = false;

  static String _lastHeard = '';
  static void Function(String heard, String feedback)? _onFeedback;
  static void Function()? _onDone;
  static BuildContext? _ctx;

  static void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onResult':
          final text = (call.arguments ?? '').toString();
          _lastHeard = text;
          final action = _parse(text);
          _onFeedback?.call(text, action.feedback);
          if (_ctx != null) _execute(_ctx!, action);
          _onDone?.call();
          break;
        case 'onError':
          _onFeedback?.call(_lastHeard, 'Could not hear (${call.arguments})');
          _onDone?.call();
          break;
        case 'onReady':
          _onFeedback?.call('', 'Listening… speak now');
          break;
      }
      return null;
    });
  }

  /// Start listening. Feedback fires with what was heard + the action taken.
  static Future<void> listen(
    BuildContext context, {
    required void Function(String heard, String feedback) onFeedback,
    required void Function() onDone,
  }) async {
    _ensureWired();
    _ctx = context;
    _onFeedback = onFeedback;
    _onDone = onDone;
    try {
      await _channel.invokeMethod('listen');
    } on PlatformException catch (e) {
      onFeedback('', 'Voice not available: ${e.message}');
      onDone();
    }
  }

  // ---- command parsing ----
  static _VAction _parse(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.isEmpty) return _VAction('unknown', feedback: "Didn't catch that");

    if (_has(t, ['dashboard', 'home'])) return _VAction('tab', tabIndex: 0, feedback: 'Opening Dashboard');
    if (_has(t, ['activity', 'report', 'reports'])) return _VAction('tab', tabIndex: 1, feedback: 'Opening Activity');
    if (_has(t, ['live track', 'live tracking', 'map', 'track', 'live'])) return _VAction('tab', tabIndex: 2, feedback: 'Opening Live Map');
    if (_has(t, ['alert', 'alerts', 'notification', 'notifications'])) return _VAction('tab', tabIndex: 3, feedback: 'Opening Alerts');
    if (_has(t, ['profile', 'account', 'settings'])) return _VAction('tab', tabIndex: 4, feedback: 'Opening Profile');

    if (_has(t, ['search', 'find', 'show me', 'locate', 'where is', 'vehicle'])) {
      final q = _extract(t);
      if (q.isNotEmpty) return _VAction('search', query: q, feedback: 'Searching "$q"');
    }
    final bare = _extract(t);
    if (bare.isNotEmpty && RegExp(r'[0-9]').hasMatch(bare)) {
      return _VAction('search', query: bare, feedback: 'Searching "$bare"');
    }
    return _VAction('unknown', feedback: 'Try: "dashboard", "live track", "search 420"');
  }

  static bool _has(String t, List<String> keys) => keys.any((k) => t.contains(k));

  static String _extract(String t) {
    var s = t;
    for (final w in ['search for', 'search', 'find', 'show me', 'show', 'locate', 'where is', 'vehicle', 'the', 'open', 'live track', 'on map', 'map']) {
      s = s.replaceAll(w, ' ');
    }
    s = _digits(s);
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
  }

  static String _digits(String s) {
    const m = {'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4', 'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9'};
    var out = s;
    m.forEach((w, d) => out = out.replaceAll(RegExp('\\b$w\\b'), d));
    return out;
  }

  static void _execute(BuildContext context, _VAction a) {
    final shell = MainShell.of(context);
    if (a.type == 'tab') {
      shell?.goTo(a.tabIndex!);
    } else if (a.type == 'search') {
      final q = (a.query ?? '').toLowerCase();
      final match = ApiService.cachedDevices.where(
        (u) => (u['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains(q),
      );
      if (match.isNotEmpty) {
        shell?.focusVehicleOnMap(match.first['id']);
      } else {
        shell?.goTo(2);
      }
    }
  }
}

class _VAction {
  final String type;
  final int? tabIndex;
  final String? query;
  final String feedback;
  _VAction(this.type, {this.tabIndex, this.query, required this.feedback});
}
