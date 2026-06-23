import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _remember = true;
  String? _error;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    final email = ApiService.userEmail;
    if (email != null && email.isNotEmpty) _email.text = email;
    _maybeBiometricLogin();
  }

  // On login page open: if biometric login is enabled, auto-prompt face/finger.
  Future<void> _maybeBiometricLogin() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() => _bioAvailable = available && enabled);
    if (available && enabled) {
      // small delay so the page is built before the system prompt appears
      await Future.delayed(const Duration(milliseconds: 350));
      _biometricLogin();
    }
  }

  Future<void> _biometricLogin() async {
    final creds = await BiometricService.authenticate();
    if (!mounted || creds == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.login(creds['email']!, creds['password']!);
    if (!mounted) return;
    if (res['ok'] == true) {
      NotificationService.startEventPolling();
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // stored credentials no longer valid (e.g. password changed) — clear them
      await BiometricService.disable();
      setState(() {
        _loading = false;
        _bioAvailable = false;
        _error = 'Saved login expired. Please sign in with your password.';
      });
    }
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (res['ok'] == true) {
      NotificationService.startEventPolling();
      // offer to enable biometric login (only if the device supports it and
      // it isn't already enabled)
      final canBio = await BiometricService.isAvailable();
      final already = await BiometricService.isEnabled();
      if (mounted && canBio && !already) {
        await _promptEnableBiometric(_email.text.trim(), _pass.text);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _loading = false;
        _error = res['error']?.toString() ?? 'Login failed';
      });
    }
  }

  Future<void> _promptEnableBiometric(String email, String password) async {
    final enable = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: const [
          Icon(Icons.fingerprint, color: AppColors.teal),
          SizedBox(width: 10),
          Expanded(child: Text('Enable Quick Login?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ]),
        content: const Text(
          'Use your Face or Fingerprint to log in next time — no need to type your password.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not Now')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (enable == true) {
      await BiometricService.enable(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final logoW = (screenW * 0.78).clamp(220.0, 340.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // brand header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 30, 24, 6),
                            child: Column(
                              children: [
                                Image.asset('assets/logo.png',
                                    width: logoW, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _logoFallback()),
                                const SizedBox(height: 6),
                                const Text('हर रास्ते पर, हमारी नज़र',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF5A6A6A), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          // card — fills remaining height like web flex:1
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                boxShadow: [BoxShadow(color: Color(0x0F0E5C5C), blurRadius: 24, offset: Offset(0, -2))],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Center(child: Text('Welcome Back!', style: TextStyle(color: AppColors.teal, fontSize: 23, fontWeight: FontWeight.w700))),
                                        const SizedBox(height: 4),
                                        const Center(child: Text('Login to your account', style: TextStyle(color: AppColors.muted, fontSize: 14))),
                                        const SizedBox(height: 22),
                                        if (_error != null) _banner(_error!),
                                        _inputField(controller: _email, hint: 'Email Address', icon: Icons.mail_outline, keyboard: TextInputType.emailAddress),
                                        const SizedBox(height: 16),
                                        _inputField(
                                          controller: _pass,
                                          hint: 'Password',
                                          icon: Icons.lock_outline,
                                          obscure: _obscure,
                                          trailing: GestureDetector(
                                            onTap: () => setState(() => _obscure = !_obscure),
                                            child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 22, color: AppColors.muted),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(2, 6, 2, 18),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              GestureDetector(
                                                onTap: () => setState(() => _remember = !_remember),
                                                child: Row(children: [
                                                  Container(
                                                    width: 22, height: 22,
                                                    decoration: BoxDecoration(
                                                      color: _remember ? AppColors.teal : Colors.white,
                                                      borderRadius: BorderRadius.circular(7),
                                                      border: Border.all(color: _remember ? AppColors.teal : const Color(0xFFC2CFCF), width: 2),
                                                    ),
                                                    child: _remember ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                                  ),
                                                  const SizedBox(width: 9),
                                                  const Text('Remember Me', style: TextStyle(fontSize: 13.5, color: Color(0xFF3A4A4A), fontWeight: FontWeight.w500)),
                                                ]),
                                              ),
                                              GestureDetector(
                                                onTap: _forgotPassword,
                                                child: const Text('Forgot Password?', style: TextStyle(fontSize: 13.5, color: AppColors.teal, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _loginButton(),
                                        if (_bioAvailable)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                onPressed: _loading ? null : _biometricLogin,
                                                icon: const Icon(Icons.fingerprint, size: 22, color: AppColors.teal),
                                                label: const Text('Login with Face / Fingerprint', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: AppColors.teal, width: 1.4),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
                                          child: Row(children: const [
                                            Expanded(child: Divider(color: Color(0xFFE3EAE8), thickness: 1)),
                                            Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: TextStyle(color: AppColors.muted, fontSize: 13))),
                                            Expanded(child: Divider(color: Color(0xFFE3EAE8), thickness: 1)),
                                          ]),
                                        ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _getNewGps,
                                            icon: const Icon(Icons.add_location_alt_outlined, size: 21),
                                            label: const Text('Get a New GPS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.teal,
                                              side: const BorderSide(color: AppColors.teal, width: 1.5),
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  // skyline footer pinned to bottom of card
                                  SizedBox(height: 80, width: double.infinity, child: CustomPaint(painter: _SkylinePainter())),
                                  Container(
                                    width: double.infinity,
                                    color: AppColors.teal,
                                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                                    child: const Text('Version 1.0.0', textAlign: TextAlign.center, style: TextStyle(color: Color(0xEBFFFFFF), fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoFallback() {
    return Column(children: [
      const Icon(Icons.location_on, size: 70, color: AppColors.red),
      const Text('Bharat GPS Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.teal)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
        SizedBox(width: 26, height: 3, child: ColoredBox(color: AppColors.amber)),
        SizedBox(width: 8),
        Text("INDIA'S BEST VEHICLE TRACKING SYSTEM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3A4A4A))),
      ]),
    ]);
  }

  Widget _banner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF6CECE)),
      ),
      child: Text(msg, style: const TextStyle(color: Color(0xFFB42424), fontSize: 13, height: 1.4)),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA8A8), fontSize: 15),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(icon, size: 22, color: AppColors.teal),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: trailing != null ? Padding(padding: const EdgeInsets.only(right: 15, left: 8), child: trailing) : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9E2E0), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
      ),
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          disabledBackgroundColor: const Color(0xFF9DB6B6),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: const Color(0x470E5C5C),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                SizedBox(width: 12),
                Text('Locating account…', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ])
            : Stack(
                alignment: Alignment.center,
                children: const [
                  Text('Login', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Positioned(right: 4, child: Icon(Icons.arrow_forward, size: 22, color: Colors.white)),
                ],
              ),
      ),
    );
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset — please contact support or use the web portal')));
  }

  void _getNewGps() async {
    final uri = Uri.parse('http://bharatgps.store');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open bharatgps.store')));
      }
    }
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE7ECEA)..strokeWidth = 1;
    const gap = 46.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x99FFFFFF));
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final fill = Paint()..color = AppColors.teal;
    final faint = Paint()..color = const Color(0x590E5C5C);

    final back = Path()..moveTo(0, h * 0.55);
    for (double x = 0; x <= w; x += w / 16) {
      back.lineTo(x, h * (0.4 + (x.toInt() % 3) * 0.08));
    }
    back..lineTo(w, h)..lineTo(0, h)..close();
    canvas.drawPath(back, faint);

    final front = Path()..moveTo(0, h);
    double x = 0;
    final heights = [0.5, 0.35, 0.6, 0.42, 0.7, 0.3, 0.55, 0.4, 0.65, 0.38, 0.5, 0.45, 0.6, 0.33];
    final bw = w / heights.length;
    for (int i = 0; i < heights.length; i++) {
      final bh = h * heights[i];
      front..lineTo(x, h - bh)..lineTo(x + bw, h - bh);
      x += bw;
    }
    front..lineTo(w, h)..close();
    canvas.drawPath(front, fill);

    final cx = w * 0.5;
    canvas.drawRect(Rect.fromLTWH(cx - 14, h * 0.25, 28, h * 0.75), fill);
    canvas.drawRect(Rect.fromLTWH(cx - 2, h * 0.1, 4, h * 0.18), fill);
    canvas.drawCircle(Offset(w * 0.28, h * 0.45), 9, fill);
    canvas.drawRect(Rect.fromLTWH(w * 0.28 - 2, h * 0.45, 4, h * 0.55), fill);
    canvas.drawCircle(Offset(w * 0.72, h * 0.4), 11, fill);
    canvas.drawRect(Rect.fromLTWH(w * 0.72 - 2, h * 0.4, 4, h * 0.6), fill);

    final trail = Paint()..color = const Color(0xD9FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2;
    final path = Path()
      ..moveTo(w * 0.05, h * 0.7)
      ..quadraticBezierTo(w * 0.3, h * 0.45, w * 0.5, h * 0.62)
      ..quadraticBezierTo(w * 0.7, h * 0.78, w * 0.95, h * 0.6);
    _drawDashed(canvas, path, trail);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 5.0, gap = 7.0;
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = dist + dash;
        canvas.drawPath(metric.extractPath(dist, next.clamp(0, metric.length)), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
