import 'package:flutter/widgets.dart';

/// Global keys used by the feature tour to locate real buttons on screen.
/// Attaching a key to a widget does NOT change its behaviour — it only lets
/// the tour read that widget's position so it can spotlight it and place a
/// tooltip beside it. Each key is optional; if a screen isn't built yet, the
/// tour simply skips that step.
class TourKeys {
  // Map screen controls
  static final mapLocate = GlobalKey(debugLabel: 'tour_mapLocate');
  static final mapShare = GlobalKey(debugLabel: 'tour_mapShare');
  static final mapNames = GlobalKey(debugLabel: 'tour_mapNames');
  static final mapCompass = GlobalKey(debugLabel: 'tour_mapCompass');
  static final mapGeofence = GlobalKey(debugLabel: 'tour_mapGeofence');
  static final mapTypes = GlobalKey(debugLabel: 'tour_mapTypes');

  // Dashboard
  static final dashStats = GlobalKey(debugLabel: 'tour_dashStats');
  static final dashList = GlobalKey(debugLabel: 'tour_dashList');

  // Activity
  static final activityStatus = GlobalKey(debugLabel: 'tour_activityStatus');

  // Alerts
  static final alertsCreate = GlobalKey(debugLabel: 'tour_alertsCreate');
  static final alertsGeofence = GlobalKey(debugLabel: 'tour_alertsGeofence');

  // Profile
  static final profileStore = GlobalKey(debugLabel: 'tour_profileStore');
}
