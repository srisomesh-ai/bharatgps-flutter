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

// Back-button behavior:
// - On a non-dashboard main tab: back goes to Dashboard.
// - On Dashboard: first back shows "press again to exit", second back minimizes app.
class _BackHandler extends StatefulWidget {
  final Widget child;
  final bool isDashboard;
  const _BackHandler({required this.child, this.isDashboard = false});
  @override
  State<_BackHandler> createState() => _BackHandlerState();
}

class _BackHandlerState extends State<_BackHandler> {
  DateTime? _lastBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (!widget.isDashboard) {
          Navigator.pushReplacementNamed(context, '/dashboard');
          return;
        }
        // dashboard: double-back to minimize
        final now = DateTime.now();
        if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
          _lastBack = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
          );
        } else {
          SystemNavigator.pop(); // minimize / close
        }
      },
      child: widget.child,
    );
  }
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
        '/dashboard': (_) => const _BackHandler(isDashboard: true, child: DashboardScreen()),
        '/activity': (_) => const _BackHandler(child: ActivityScreen()),
        '/map': (_) => const _BackHandler(child: MapScreen()),
        '/alerts': (_) => const _BackHandler(child: AlertsScreen()),
        '/profile': (_) => const _BackHandler(child: ProfileScreen()),
        '/notification-settings': (_) => const NotificationSettingsScreen(),
      },
    );
  }
}
