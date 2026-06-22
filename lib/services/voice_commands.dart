import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/api_service.dart';
import 'main_shell.dart';

/// Result of parsing a spoken command — what the app should do.
class VoiceAction {
  final String type; // 'tab' | 'search' | 'unknown'
  final int? tabIndex; // for 'tab'
  final String? query; // for 'search'
  final String feedback; // what to show the user
  VoiceAction(this.type, {this.tabIndex, this.query, required this.feedback});
}

class VoiceCommands {
  static final SpeechToText _speech = SpeechToText();
  static bool _available = false;

  static Future<bool> init() async {
    try {
      _available = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  static bool get isListening => _speech.isListening;

  /// Listen for a single command. onResult fires with the final recognized text.
  static Future<void> listen({required void Function(String text) onResult, required void Function() onDone}) async {
    if (!_available) {
      final ok = await init();
      if (!ok) {
        onDone();
        return;
      }
    }
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult) {
          onResult(r.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_IN',
      cancelOnError: true,
      partialResults: false,
    );
    // poll for completion
    _speech.statusListener = (status) {
      if (status == 'done' || status == 'notListening') onDone();
    };
  }

  static Future<void> stop() async => _speech.stop();

  /// Turn recognized text into an action (simple keyword matching).
  static VoiceAction parse(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.isEmpty) return VoiceAction('unknown', feedback: "Didn't catch that");

    // --- tab navigation ---
    if (_has(t, ['dashboard', 'home'])) {
      return VoiceAction('tab', tabIndex: 0, feedback: 'Opening Dashboard');
    }
    if (_has(t, ['activity', 'report', 'reports', 'fleet'])) {
      return VoiceAction('tab', tabIndex: 1, feedback: 'Opening Activity');
    }
    if (_has(t, ['live track', 'live tracking', 'map', 'track', 'live'])) {
      return VoiceAction('tab', tabIndex: 2, feedback: 'Opening Live Map');
    }
    if (_has(t, ['alert', 'alerts', 'notification', 'notifications'])) {
      return VoiceAction('tab', tabIndex: 3, feedback: 'Opening Alerts');
    }
    if (_has(t, ['profile', 'account', 'settings'])) {
      return VoiceAction('tab', tabIndex: 4, feedback: 'Opening Profile');
    }

    // --- search for a vehicle ---
    // e.g. "search for 420", "find AP16CA0142", "show vehicle 5567"
    if (_has(t, ['search', 'find', 'show me', 'locate', 'where is', 'vehicle'])) {
      final q = _extractQuery(t);
      if (q.isNotEmpty) {
        return VoiceAction('search', query: q, feedback: 'Searching for "$q"');
      }
    }

    // a bare number or plate-like token also means search
    final bare = _extractQuery(t);
    if (bare.isNotEmpty && RegExp(r'[0-9]').hasMatch(bare)) {
      return VoiceAction('search', query: bare, feedback: 'Searching for "$bare"');
    }

    return VoiceAction('unknown', feedback: 'Try: "open dashboard", "live track", or "search 420"');
  }

  static bool _has(String t, List<String> keys) => keys.any((k) => t.contains(k));

  // pull the vehicle identifier out of a command, converting number words to digits
  static String _extractQuery(String t) {
    var s = t;
    for (final w in ['search for', 'search', 'find', 'show me', 'show', 'locate', 'where is', 'vehicle', 'the', 'open', 'live track', 'on map', 'map']) {
      s = s.replaceAll(w, ' ');
    }
    s = _wordsToDigits(s);
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), '').trim();
    return s;
  }

  static String _wordsToDigits(String s) {
    const map = {
      'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'four': '4',
      'five': '5', 'six': '6', 'seven': '7', 'eight': '8', 'nine': '9',
      'hundred': '00', 'thousand': '000',
    };
    var out = s;
    map.forEach((w, d) => out = out.replaceAll(RegExp('\\b$w\\b'), d));
    return out;
  }

  /// Execute the parsed action against the running app.
  static void execute(BuildContext context, VoiceAction a) {
    final shell = MainShell.of(context);
    switch (a.type) {
      case 'tab':
        shell?.goTo(a.tabIndex!);
        break;
      case 'search':
        // try to find a matching vehicle by name; if found, focus it on the map
        final q = (a.query ?? '').toLowerCase();
        final match = ApiService.cachedDevices.where((u) => (u['name'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '').contains(q));
        if (match.isNotEmpty) {
          shell?.focusVehicleOnMap(match.first['id']);
        } else {
          shell?.goTo(2); // open the map anyway
        }
        break;
    }
  }
}
