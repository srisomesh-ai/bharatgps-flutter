import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/map_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notification_settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await ApiService.loadSession();

  // Firebase + notifications (won't crash the app if google-services.json is missing
  // until you add it; wrapped in try so the rest of the app still runs).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    await NotificationService.init();
  } catch (_) {
    // Firebase not configured yet — app still works.
    // Still set up local notifications + in-app alert polling so app alerts work.
    try {
      await NotificationService.initLocalOnly();
    } catch (_) {}
  }

  runApp(const BharatGpsApp());
}

class BharatGpsApp extends StatelessWidget {
  const BharatGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat GPS Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: ApiService.isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/activity': (_) => const ActivityScreen(),
        '/map': (_) => const MapScreen(),
        '/alerts': (_) => const AlertsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/notification-settings': (_) => const NotificationSettingsScreen(),
      },
    );
  }
}
