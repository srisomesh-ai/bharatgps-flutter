import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

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
  String? _error;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter email and password');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.login(_email.text.trim(), _pass.text);
    if (!mounted) return;
    if (res['ok'] == true) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() {
        _loading = false;
        _error = res['error']?.toString() ?? 'Login failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.teal, AppColors.teal2],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.location_on, size: 50, color: AppColors.teal),
                  ),
                  const SizedBox(height: 18),
                  const Text('Bharat GPS Tracker',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Fleet tracking made simple',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign In',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.ink)),
                        const SizedBox(height: 18),
                        _field(_email, 'Email', Icons.mail_outline),
                        const SizedBox(height: 14),
                        _field(_pass, 'Password', Icons.lock_outline, obscure: _obscure, toggle: () {
                          setState(() => _obscure = !_obscure);
                        }),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12.5)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                            child: _loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('v1.0.0', style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false, VoidCallback? toggle}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: hint == 'Email' ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.muted),
        suffixIcon: toggle != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.muted),
                onPressed: toggle)
            : null,
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
