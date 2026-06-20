# Bharat GPS Tracker — Flutter Android App

Native Android app (Flutter/Dart) for the BharatGPS fleet tracking platform.
It talks **directly** to the BharatGPS (Traccar-based) API — no PHP proxy required.

## Features
- **Login** — authenticates across bharatgps.com / .in / .school
- **Dashboard** — fleet summary (Total/Running/Idle/Offline), searchable vehicle list
- **Live Map** — real-time vehicle positions (flutter_map), tap a vehicle for details
- **Vehicle Detail** — speed, engine state, location, and **Engine Cut-Off** (immobilizer) for supported devices
- **Fleet Activity** — per-vehicle reports with load-on-demand today's km/hours/max-speed
- **History Playback** — animated route replay with play/seek/speed and trip stops
- **Alerts** — create Over-Speed / Movement / Engine / Power-Cut / Low-Battery alerts; toggle, delete; events history
- **Profile** — user info, fleet stats, plan, settings menu, logout

## Project structure
```
lib/
  main.dart                 app entry + routing
  theme/app_theme.dart      colors, helpers
  services/api_service.dart  direct BharatGPS API calls
  widgets/bottom_nav.dart    shared bottom navigation
  screens/                   login, dashboard, activity, map, history_map, alerts, profile
```

## Build the APK

You need the **Flutter SDK** installed (https://docs.flutter.dev/get-started/install).

```bash
# 1. get dependencies
flutter pub get

# 2. (first time) generate android wrappers if missing
flutter create . --platforms=android --org com.bharatgps

# 3. run on a connected device / emulator
flutter run

# 4. build a release APK
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

### Easiest path (no local setup)
Use **Codemagic** or **GitHub Actions** to build the APK in the cloud, or open the
project in **Android Studio** (File → Open → this folder) and press Run.

## API
All requests go to `https://{server}/api/...` using the Traccar endpoints:
`login`, `get_devices`, `get_history_messages`, `send_command_data`,
`send_gprs_command`, `get_alerts`, `add_alert`, `change_active_alert`,
`destroy_alert`, `get_events`, `get_user_data`.

The login session (api hash + server) is stored with `shared_preferences`.

## Notes
- `usesCleartextTraffic` is enabled for compatibility; production should prefer HTTPS only.
- Engine Cut-Off and Power-Cut/Low-Battery alerts depend on device/server support.
- Min SDK 21 (Android 5.0+), target SDK 34.
