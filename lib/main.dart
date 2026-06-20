import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/map_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await ApiService.loadSession();
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
      },
    );
  }
}
